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

proc newParser*(tokens: seq[Token], errorObj: Error): Parser =
  return Parser(
    error: errorObj,
    tokens: tokens,
    current: 0
  )

# ----------------------------------------------------------------------

# forward declaration
proc expression(p: var Parser): Expr
proc parseBlock(p: var Parser): seq[Stmt]
proc ifStatement(p: var Parser): Stmt
proc whileStatement(p: var Parser): Stmt
proc forStatement(p: var Parser): Stmt

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

proc expect(p: var Parser, ttypes: seq[TokenType], message: string): Token {.discardable.} =
  for i in ttypes:
    if i == p.currentToken().kind: return p.advance()
  error(p.error, p.currentToken().line, "SyntaxError", message)

proc primary(p: var Parser): Expr =
  if p.doesMatch(True): return LiteralExpr(kind: True, value: "true")
  elif p.doesMatch(False): return LiteralExpr(kind: False, value: "false")
  elif p.doesMatch(Null): return LiteralExpr(kind: Null, value: "null")

  if p.doesMatch(Int, Float, String): return LiteralExpr(kind: p.previousToken().kind, value: p.previousToken().value)
  elif p.doesMatch(Identifier): return VariableExpr(name: p.previousToken())
  elif p.doesMatch(LeftParen):
    let expre = p.expression()
    p.expect(RightParen, "Expected ')'")
    return GroupingExpr(expression: expre)
  error(p.error, p.currentToken().line, "SyntaxError", "Expected an expression")

proc unary(p: var Parser): Expr =
  if p.doesMatch(Bang, Minus):
    return UnaryExpr(operator: p.previousToken(), right: p.unary())
  return p.primary()

proc factor(p: var Parser): Expr = 
  var expre: Expr = p.unary()
  while p.doesMatch(Slash, Star):
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
    else:
      error(p.error, equals.line, "SyntaxError", "Invalid assignment target")
  return expre

proc expression(p: var Parser): Expr = return p.assignment()

proc exprStmt(p: var Parser): Stmt =
  let expre = p.expression()
  p.expect(SemiColon, "Expected ';'")
  return ExprStmt(expression: expre)

proc statement(p: var Parser): Stmt =
  if p.doesMatch(LeftBrace): return BlockStmt(statements: p.parseBlock())
  elif p.doesMatch(If): return p.ifStatement()
  elif p.doesMatch(While): return p.whileStatement()
  elif p.doesMatch(For): return p.forStatement()
  return p.exprStmt()

proc varDeclaration(p: var Parser): Stmt = 
  let name = p.expect(Identifier, "Expected an identifier")
  var init: Expr
  if p.doesMatch(Equals): init = p.expression()
  p.expect(SemiColon, "Expected ';' after variable declaration")
  return VariableStmt(name: name, init: init)

proc forStatement(p: var Parser): Stmt =
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
  
  var body = p.statement()
  if not increment.isNil: body = BlockStmt(statements: @[body, ExprStmt(expression: increment)])
  if condition.isNil: condition = LiteralExpr(kind: True, value: "")
  body = WhileStmt(condition: condition, body: body)
  if not init.isNil: body = BlockStmt(statements: @[init, body])
  return body

proc whileStatement(p: var Parser): Stmt =
  p.expect(LeftParen, "Expected '(' after 'while'")
  let condition = p.expression()
  p.expect(RightParen, "Expected ')' after while condition")
  let body = p.statement()
  return WhileStmt(condition: condition, body: body)

proc ifStatement(p: var Parser): Stmt =
  p.expect(LeftParen, "Expected '(' after 'if'")
  let condition = p.expression()
  p.expect(RightParen, "Expected ')' after if condition")
  let thenBranch = p.statement()
  # TODO: add elif branches
  var elseBranch: Stmt
  if p.doesMatch(Else):
    elseBranch = p.statement()
  return IfStmt(condition: condition, thenBranch: thenBranch, elseBranch: elseBranch)

proc declaration(p: var Parser): Stmt =
  if p.doesMatch(Let): return p.varDeclaration()
  elif p.doesMatch(Const): return p.varDeclaration()
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