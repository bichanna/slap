#
# parser.nim
# SLAP
#
# Created by Nobuharu Shimazu on 2/15/2022
#

import error
import obj/[token, node]
import hashes

const ErrorName = "SyntaxError"

type
  # Parser takes in a list of tokens (seq[Token]) and 
  # generates an abstract syntax tree.
  Parser* = object
    tokens*: seq[Token]
    current*: int
    loopDepth*: int
    statements*: seq[Stmt]

# newParser creates a new Parser and returns it.
proc newParser*(tokens: seq[Token]): Parser =
  return Parser(
    tokens: tokens,
    current: 0,
    loopDepth: 0,
    statements: @[]
  )

# ----------------------------------------------------------------------

# forward declarations
proc expression(p: var Parser): Expr
proc parseBlock(p: var Parser): seq[Stmt]
proc ifStatement(p: var Parser): Stmt
proc whileStatement(p: var Parser): Stmt
proc forStatement(p: var Parser): Stmt
proc returnStatement(p: var Parser): Stmt
proc getParams(p: var Parser, kind: string): seq[FuncArg]
proc functionBody(p: var Parser, kind: string): FuncExpr
proc statement(p: var Parser): Stmt
proc parse*(p: var Parser): seq[Stmt]

# This is for one-line, anonymous functions.
var dontNeedSemicolon = false

# returns the previous token
proc previousToken(p: var Parser): Token = return p.tokens[p.current - 1]

# returns the current token
proc currentToken(p: var Parser): Token = return p.tokens[p.current]

# checks if EOF is reached
proc isAtEnd(p: var Parser): bool = return p.currentToken().kind == EOF

# chcecks if the current token is of the expected type
proc checkCurrentTok(p: var Parser, ttype: TokenType): bool =
  if p.isAtEnd(): return false
  else: return p.currentToken().kind == ttype

# checks if the next token is of the expected type
proc checkNextTok(p: var Parser, ttype: TokenType): bool =
  if p.isAtEnd(): return false
  elif p.tokens[p.current+1].kind == EOF: return false
  else: return p.tokens[p.current+1].kind == ttype

# returns the current token and moves to the next one
proc advance(p: var Parser): Token {.discardable.} = 
  if not p.isAtEnd(): p.current += 1
  return p.previousToken()

# checks if the current token is in the given types
proc doesMatch(p: var Parser, types: varargs[TokenType]): bool =
  for i in types:
    if p.checkCurrentTok(i):
      p.advance()
      return true
  return false

# This checks wheter the current token is the expected type or not.
# If not, throws an error.
proc expect(p: var Parser, ttype: TokenType, message: string): Token {.discardable.} =
  if p.checkCurrentTok(ttype): return p.advance()
  else: 
    error(p.currentToken(), ErrorName, message)

proc primary(p: var Parser): Expr =
  if p.doesMatch(True): return LiteralExpr(kind: True, value: "true")

  elif p.doesMatch(False): return LiteralExpr(kind: False, value: "false")

  elif p.doesMatch(Null): return LiteralExpr(kind: Null, value: "null")

  elif p.doesMatch(Self): return SelfExpr(keyword: p.previousToken())

  elif p.doesMatch(Super):
    let keyword = p.previousToken()
    p.expect(Dot, "Expected '.' after 'super'")
    let m = p.expect(Identifier, "Expected superclass method name")
    return SuperExpr(keyword: keyword, classMethod: m)

  elif p.doesMatch(Int, Float, String): return LiteralExpr(kind: p.previousToken().kind, value: p.previousToken().value)

  elif p.doesMatch(Identifier):
    let name = p.previousToken()
    return VariableExpr(name: name)

  elif p.doesMatch(LeftParen):
    let expre = p.expression()
    p.expect(RightParen, "Expected ')'")
    return GroupingExpr(expression: expre)

  elif p.doesMatch(LeftBracket):            # list literal
    let keyword = p.previousToken()
    
    if p.doesMatch(RightBracket):
      return ListLiteralExpr(values: @[], keyword: keyword)
    
    var values: seq[Expr]
    values.add(p.expression())
    
    while p.doesMatch(Comma):
      values.add(p.expression())
    p.expect(RightBracket, "Expected ']'")
    
    return ListLiteralExpr(values: values, keyword: keyword)

  elif p.doesMatch(LeftBrace):              # map literal
    let keyword = p.previousToken()
    if p.doesMatch(RightBrace):
      return MapLiteralExpr(keys: @[], values: @[], keyword: keyword)

    var keys: seq[Expr]
    var values: seq[Expr]

    keys.add(p.expression())
    p.expect(Colon, "Expected ':' after key")
    values.add(p.expression())

    while p.doesMatch(Comma):
      keys.add(p.expression())
      p.expect(Colon, "Expected ':' after key")
      values.add(p.expression())
    p.expect(RightBrace, "Expected '}'")

    return MapLiteralExpr(keys: keys, values: values, keyword: keyword)

  elif p.doesMatch(Define):
    var params = p.getParams("function")
    if p.checkNextTok(RightBrace):
      return p.functionBody("function")
    else:
      p.expect(FatRightArrow, "Expected '=>' before function body")
      dontNeedSemicolon = true
      var statement = p.statement()
      dontNeedSemicolon = false
      var body: seq[Stmt]; body.add(statement)
      return FuncExpr(parameters: params, body: body)
  error(p.currentToken(), ErrorName, "Expected an expression")

proc finishCall(p: var Parser, callee: Expr, arg: Expr): Expr =
  var arguments: seq[Expr]
  if not arg.isNil: arguments.add(arg)
  if not p.checkCurrentTok(RightParen):
    arguments.add(p.expression())
    while p.doesMatch(Comma):
      if arguments.len >= 256:
        error(p.currentToken(), ErrorName, "Cannot have more than 256 arguments")
      arguments.add(p.expression())
  let paren = p.expect(RightParen, "Expected ')' after arguments")
  # check for <-
  if p.doesMatch(LeftArrow):
    arguments.add(p.expression())
  return CallExpr(callee: callee, paren: paren, arguments: arguments)

proc call(p: var Parser, arg: Expr = nil): Expr =
  var expre: Expr = p.primary()
  while true:
    if p.doesMatch(LeftParen):
      expre = p.finishCall(expre, arg)
    elif p.doesMatch(Dot):
      let name = p.expect(Identifier, "Expected property name after '.'")
      expre = GetExpr(instance: expre, name: name)
    elif p.doesMatch(RightArrow):
      expre = p.call(expre)
      break
    elif p.doesMatch(At):
      let token = p.previousToken()
      p.expect(LeftBracket, "Expected '['")
      let indexOrKey = p.expression()
      p.expect(RightBracket, "Expected ']'")
      expre = ListOrMapVariableExpr(variable: expre, indexOrKey: indexOrKey, token: token)
    else:
      break
  return expre

proc unary(p: var Parser): Expr =
  if p.doesMatch(Bang, Minus):
    return UnaryExpr(operator: p.previousToken(), right: p.unary())
  return p.call()

proc factor(p: var Parser): Expr = 
  var expre: Expr = p.unary()
  while p.doesMatch(Slash, Star, Modulo):
    expre = BinaryExpr(left: expre, operator: p.previousToken(), right: p.unary())
  return expre

proc term(p: var Parser): Expr =
  var expre: Expr = p.factor()
  while p.doesMatch(Minus, Plus):
    expre = BinaryExpr(left: expre, operator: p.previousToken(), right: p.factor())
  return expre

proc comparison(p: var Parser): Expr = 
  var expre: Expr = p.term()
  while p.doesMatch(Greater, GreaterEqual, Less, LessEqual):
    expre = BinaryExpr(left: expre, operator: p.previousToken(), right: p.term())
  return expre

proc equality(p: var Parser): Expr = 
  var expre: Expr = p.comparison()
  while p.doesMatch(BangEqual, EqualEqual):
    expre = BinaryExpr(left: expre, operator: p.previousToken(), right: p.comparison())
  return expre

proc andExpr(p: var Parser): Expr =
  var expre = p.equality();
  while p.doesMatch(And):
    expre = LogicalExpr(left: expre, operator: p.previousToken(), right: p.equality())
  return expre

proc orExpr(p: var Parser): Expr =
  var expre = p.andExpr()
  while p.doesMatch(Or):
    expre = LogicalExpr(left: expre, operator: p.previousToken(), right: p.andExpr())
  return expre

proc assignment(p: var Parser): Expr =
  var expre = p.orExpr()
  if p.doesMatch(Equals):
    let equals = p.previousToken()
    let value = p.assignment()

    if expre of VariableExpr:
      let name = VariableExpr(expre).name
      return AssignExpr(name: name, value: value)
    elif expre of ListOrMapVariableExpr:
      let listOrMap = ListOrMapVariableExpr(expre)
      let variable = listOrMap.variable
      let indexOrKey = listOrMap.indexOrKey
      let token = listOrMap.token
      return ListOrMapAssignExpr(variable: variable, indexOrKey: indexOrKey, value: value, token: token)
    elif expre of GetExpr:
      let get = GetExpr(expre)
      return SetExpr(instance: get.instance, name: get.name, value: value)
    else:
      error(equals, ErrorName, "Invalid assignment target")
  
  elif p.doesMatch(PlusEqual) or p.doesMatch(MinusEqual) or p.doesMatch(StarEqual) or p.doesMatch(SlashEqual):
    var ope = p.previousToken()
    let value = p.assignment()
    return BinaryExpr(left: expre, operator: ope, right: value)

  elif p.doesMatch(PlusPlus) or p.doesMatch(MinusMinus):
    return BinaryExpr(left: expre, operator: p.previousToken(), right: LiteralExpr(kind: Int, value: "1"))

  return expre

proc expression(p: var Parser): Expr = return p.assignment()

proc exprStmt(p: var Parser): Stmt =
  let expre = p.expression()
  if not dontNeedSemicolon: p.expect(SemiColon, "Expected ';'")
  return ExprStmt(expression: expre)

proc breakStatement(p: var Parser): Stmt =
  if p.loopDepth == 0:
    error(p.previousToken(), ErrorName, "'break' can only be used inside a loop")
  if not dontNeedSemicolon: p.expect(SemiColon, "Expected ';' after 'break'")
  return BreakStmt()

proc importStatement(p: var Parser): Stmt =
  let token = p.previousToken()
  let name = p.expression()

  var imports: seq[Hash] = @[]
  if p.doesMatch(FatRightArrow):
    imports.add(p.currentToken().value.hash)
    p.advance()
    while p.doesMatch(Comma):
      imports.add(p.currentToken().value.hash)
      p.advance()
  
  if not dontNeedSemicolon: p.expect(SemiColon, "Expected ';' after import statement")
  return ImportStmt(name: name, keyword: token, imports: imports)

proc continueStatement(p: var Parser): Stmt =
  if p.loopDepth == 0:
    error(p.previousToken(), ErrorName, "'continue' can only be used inside a loop")
  if not dontNeedSemicolon: p.expect(SemiColon, "Expected ';' after 'continue'")
  return ContinueStmt()

proc statement(p: var Parser): Stmt =
  if p.doesMatch(LeftBrace): dontNeedSemicolon = false; return BlockStmt(statements: p.parseBlock())
  elif p.doesMatch(If): return p.ifStatement()
  elif p.doesMatch(While): return p.whileStatement()
  elif p.doesMatch(For): return p.forStatement()
  elif p.doesMatch(Return): return p.returnStatement()
  elif p.doesMatch(Break): return p.breakStatement()
  elif p.doesMatch(Import): return p.importStatement()
  elif p.doesMatch(Continue): return p.continueStatement()
  return p.exprStmt()

proc returnStatement(p: var Parser): Stmt =
  let keyword = p.previousToken()
  var value: Expr
  if not p.checkCurrentTok(SemiColon): value = p.expression()
  if not dontNeedSemicolon: p.expect(SemiColon, "Expected ';' after return value")
  return ReturnStmt(keyword: keyword, value: value)

proc varDeclaration(p: var Parser): Stmt = 
  let name = p.expect(Identifier, "Expected an identifier")
  var init: Expr
  if p.doesMatch(Equals): init = p.expression()
  if not dontNeedSemicolon: p.expect(SemiColon, "Expected ';' after variable declaration")
  return VariableStmt(name: name, init: init)

proc forStatement(p: var Parser): Stmt =
  let keyword = p.previousToken()
  p.expect(LeftParen, "Expected '(' after 'for'")

  var init: Stmt
  if p.doesMatch(SemiColon): discard
  elif p.doesMatch(Let): init = p.varDeclaration()
  else: init = p.exprStmt()

  var condition: Expr
  if not p.checkCurrentTok(SemiColon): condition = p.expression()
  if not dontNeedSemicolon: p.expect(SemiColon, "Expected ';' after loop condition")

  var increment: Expr
  if not p.checkCurrentTok(RightParen): increment = p.expression()
  p.expect(RightParen, "Expected ')' after for clauses")
  
  try:
    p.loopDepth += 1
    var body = p.statement()
    if not increment.isNil: body = BlockStmt(statements: @[body, ExprStmt(expression: increment)])
    if condition.isNil: condition = LiteralExpr(kind: True, value: "")
    body = WhileStmt(condition: condition, body: body, keyword: keyword)
    if not init.isNil: body = BlockStmt(statements: @[init, body])
    return body
  finally:
    p.loopDepth -= 1

proc whileStatement(p: var Parser): Stmt =
  let keyword = p.previousToken()
  p.expect(LeftParen, "Expected '(' after 'while'")
  let condition = p.expression()
  p.expect(RightParen, "Expected ')' after while condition")
  try:
    p.loopDepth += 1
    let body = p.statement()
    return WhileStmt(condition: condition, body: body, keyword: keyword)
  finally:
    p.loopDepth -= 1

proc ifStatement(p: var Parser): Stmt =
  p.expect(LeftParen, "Expected '(' after 'if'")
  let condition = p.expression()
  p.expect(RightParen, "Expected ')' after if condition")
  let thenBranch = p.statement()
  
  var elifBranches: seq[ElifStmt] = @[]
  while p.doesMatch(Elif):
    p.expect(LeftParen, "Expected '(' after 'elif'")
    let elifCondition = p.expression()
    p.expect(RightParen, "Expected ')' after if condition")
    let elifThenBranch = p.statement()
    elifBranches.add(ElifStmt(condition: elifCondition, thenBranch: elifThenBranch))

  var elseBranch: Stmt
  if p.doesMatch(Else):
    elseBranch = p.statement()
  
  return IfStmt(condition: condition, thenBranch: thenBranch, elseBranch: elseBranch, elifBranches: elifBranches)

proc getParams(p: var Parser, kind: string): seq[FuncArg] =
  p.expect(LeftParen, "Expected '(' after " & kind & "name")
  var parameters: seq[FuncArg]
  if not p.checkCurrentTok(RightParen):
    var hadDefault = false
    var hadRest = false

    while true:
      if parameters.len >= 256: error(p.currentToken(), ErrorName, "Cannot have more than 256 parameters")
      var param = p.expect(Identifier, "Expected parameter name")
      if p.doesMatch(Equals) and not hadRest: # checks for a default parameter
        var defaultValue = p.expression()
        hadDefault = true
        parameters.add(DefaultValued(paramName: param, default: defaultValue))
      elif p.doesMatch(Plus) and not hadRest: # checks for a rest parameter
        parameters.add(RestArg(paramName: param))
        hadRest = true
      else:
        if hadDefault or hadRest:
          error(param, ErrorName, "Required parameter cannot follow default parameter, and default param cannot follow rest param.")
        parameters.add(RequiredArg(paramName: param))
        
      if not p.doesMatch(Comma): break
  
  p.expect(RightParen, "Expected ')' after parameters")

  return parameters

proc functionBody(p: var Parser, kind: string): FuncExpr =
  var parameters = p.getParams(kind)
  
  p.expect(LeftBrace, "Expected '{' before " & kind & " body")
  let body = p.parseBlock()
  return FuncExpr(parameters: parameters, body: body)

proc function(p: var Parser, kind: string): FuncStmt =
  let name = p.expect(Identifier, "Expected " & kind & " name")
  return FuncStmt(name: name, function: p.functionBody(kind))

proc classDeclaration(p: var Parser): Stmt =
  let name = p.expect(Identifier, "Expected class name")
  # check for superclass
  var superclass: VariableExpr
  if p.doesMatch(LeftArrow):
    p.expect(Identifier, "Expected a superclass name")
    superclass = VariableExpr(name: p.previousToken())
  p.expect(LeftBrace, "Expected '{' before class body")
  var methods: seq[FuncStmt]
  var classMethods: seq[FuncStmt]
  while not p.checkCurrentTok(RightBrace) and not p.isAtEnd():
    let isCM = p.doesMatch(Static)
    if not isCM: methods.add(p.function("method"))
    else: classMethods.add(p.function("method"))
  p.expect(RightBrace, "Expected '}' after class body")
  return ClassStmt(name: name, methods: methods, classMethods: classMethods, superclass: superclass)

proc declaration(p: var Parser): Stmt =
  if p.doesMatch(Let): return p.varDeclaration()
  elif p.doesMatch(Const): return p.varDeclaration()
  elif p.checkCurrentTok(Define) and p.checkNextTok(Identifier):
    p.expect(Define, "") # This does not throw error because it's already checked
    return p.function("function")
  elif p.doesMatch(Class): return p.classDeclaration()
  else: return p.statement()

proc parseBlock(p: var Parser): seq[Stmt] =
  var statements: seq[Stmt] = @[]
  while not p.checkCurrentTok(RightBrace) and not p.isAtEnd():
    statements.add(p.declaration())
  p.expect(RightBrace, "Expected '}' after a block")
  return statements

# This is where all the parsing starts.
proc parse*(p: var Parser): seq[Stmt] =
  while not p.isAtEnd():
    p.statements.add(p.declaration())
  return p.statements