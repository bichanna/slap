#
# parser.nim
# SLAP
#
# Created by Nobuharu Shimazu on 2/15/2022
#

import token, error, node

type
  # Parser takes in a list of tokens (seq[Token]) and 
  # generates an abstract syntax tree
  Parser* = object
    error*: Error
    tokens*: seq[Token]
    current*: int
    loopDepth*: int

proc newParser*(tokens: seq[Token], errorObj: Error): Parser =
  return Parser(
    error: errorObj,
    tokens: tokens,
    current: 0,
    loopDepth: 0
  )

# ----------------------------------------------------------------------

# forward declaration
proc expression(p: var Parser): Expr
proc parseBlock(p: var Parser): seq[Stmt]
proc ifStatement(p: var Parser): Stmt
proc whileStatement(p: var Parser): Stmt
proc forStatement(p: var Parser): Stmt
proc returnStatement(p: var Parser): Stmt
proc functionBody(p: var Parser, kind: string): FuncExpr

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

proc expect(p: var Parser, ttype: TokenType, message: string): Token {.discardable.} =
  if p.checkCurrentTok(ttype): return p.advance()
  else: 
    error(p.error, p.currentToken().line, "SyntaxError", message)

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
    if p.doesMatch(At):
      p.expect(LeftBracket, "Expected '['")
      let index = p.expression()
      p.expect(RightBracket, "Expected ']'")
      return ListVariableExpr(name: name, index: index)
    return VariableExpr(name: name)
  elif p.doesMatch(LeftParen):
    let expre = p.expression()
    p.expect(RightParen, "Expected ')'")
    return GroupingExpr(expression: expre)
  elif p.doesMatch(LeftBracket):
    let keyword = p.previousToken()
    if p.doesMatch(RightBracket):
      return ListLiteralExpr(values: @[], keyword: keyword)
    var values: seq[Expr]
    values.add(p.expression())
    while p.doesMatch(Comma):
      values.add(p.expression())
    p.expect(RightBracket, "Expected ']'")
    return ListLiteralExpr(values: values, keyword: keyword)
  elif p.doesMatch(Define): return p.functionBody("function")

  error(p.error, p.currentToken().line, "SyntaxError", "Expected an expression")

proc finishCall(p: var Parser, callee: Expr): Expr =
  var arguments: seq[Expr]
  if not p.checkCurrentTok(RightParen):
    arguments.add(p.expression())
    while p.doesMatch(Comma):
      if arguments.len >= 256:
        error(p.error, p.currentToken().line, "SyntaxError", "Cannot have more than 256 arguments")
      arguments.add(p.expression())
  let paren = p.expect(RightParen, "Expected ')' after arguments")
  return CallExpr(callee: callee, paren: paren, arguments: arguments)

proc call(p: var Parser): Expr =
  var expre: Expr = p.primary()
  while true:
    if p.doesMatch(LeftParen):
      expre = p.finishCall(expre)
    elif p.doesMatch(Dot):
      let name = p.expect(Identifier, "Expected property name after '.'")
      expre = GetExpr(instance: expre, name: name)
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
    elif expre of ListVariableExpr:
      let name = ListVariableExpr(expre).name
      let index = ListVariableExpr(expre).index
      return ListAssignExpr(name: name, index: index, value: value)
    elif expre of GetExpr:
      let get = GetExpr(expre)
      return SetExpr(instance: get.instance, name: get.name, value: value)
    else:
      error(p.error, equals.line, "SyntaxError", "Invalid assignment target")
  return expre

proc expression(p: var Parser): Expr = return p.assignment()

proc exprStmt(p: var Parser): Stmt =
  let expre = p.expression()
  p.expect(SemiColon, "Expected ';'")
  return ExprStmt(expression: expre)

proc breakStatement(p: var Parser): Stmt =
  if p.loopDepth == 0:
    error(p.error, p.previousToken(), "SyntaxError", "'break' can only be used inside a loop")
  p.expect(SemiColon, "Expected ';' after 'break'")
  return BreakStmt()

proc statement(p: var Parser): Stmt =
  if p.doesMatch(LeftBrace): return BlockStmt(statements: p.parseBlock())
  elif p.doesMatch(If): return p.ifStatement()
  elif p.doesMatch(While): return p.whileStatement()
  elif p.doesMatch(For): return p.forStatement()
  elif p.doesMatch(Return): return p.returnStatement()
  elif p.doesMatch(Break): return p.breakStatement()
  return p.exprStmt()

proc returnStatement(p: var Parser): Stmt =
  let keyword = p.previousToken()
  var value: Expr
  if not p.checkCurrentTok(SemiColon): value = p.expression()
  p.expect(SemiColon, "Expected ';' after return value")
  return ReturnStmt(keyword: keyword, value: value)

proc varDeclaration(p: var Parser): Stmt = 
  let name = p.expect(Identifier, "Expected an identifier")
  var init: Expr
  if p.doesMatch(Equals): init = p.expression()
  p.expect(SemiColon, "Expected ';' after variable declaration")
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
  p.expect(SemiColon, "Expected ';' after loop condition")

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

proc functionBody(p: var Parser, kind: string): FuncExpr =
  p.expect(LeftParen, "Expected '(' after " & kind & "name")
  var parameters: seq[Token]
  if not p.checkCurrentTok(RightParen):
    while true:
      if parameters.len >= 10: error(p.error, p.currentToken(), "SyntaxError", "Cannot have more than 10 parameters")
      parameters.add(p.expect(Identifier, "Expected parameter name"))
      if not p.doesMatch(Comma): break
  p.expect(RightParen, "Expected ')' after parameters")
  
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
    if not isCM: methods.add(FuncStmt(p.function("method")))
    else: classMethods.add(FuncStmt(p.function("method")))
  p.expect(RightBrace, "Expected '}' after class body")
  return ClassStmt(name: name, methods: methods, classMethods: classMethods, superclass: superclass)

proc declaration(p: var Parser): Stmt =
  if p.doesMatch(Let): return p.varDeclaration()
  elif p.doesMatch(Const): return p.varDeclaration()
  elif p.checkCurrentTok(Define) and p.checkNextTok(Identifier):
    p.expect(Define, "")
    return p.function("function")
  elif p.doesMatch(Class): return p.classDeclaration()
  else: return p.statement()

proc parseBlock(p: var Parser): seq[Stmt] =
  var statements: seq[Stmt] = @[]
  while not p.checkCurrentTok(RightBrace) and not p.isAtEnd():
    statements.add(p.declaration())
  p.expect(RightBrace, "Expected '}' after a block")
  return statements

proc parse*(p: var Parser): seq[Stmt] =
  var statements: seq[Stmt] = @[]
  while not p.isAtEnd():
    statements.add(p.declaration())
  return statements