#
# parser.nim
# SLAP
#
# Created by Nobuharu Shimazu on 2/17/2022
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
    error(p.error, p.currentToken().line, "SyntaxError", "Unterminated string, expected '\"'")

proc primary(p: var Parser): Expr =
  if p.doesMatch(True): return LiteralExpr(kind: True, value: "true")
  elif p.doesMatch(False): return LiteralExpr(kind: False, value: "false")
  elif p.doesMatch(Null): return LiteralExpr(kind: Null, value: "null")

  if p.doesMatch(Int, Float, String): return LiteralExpr(kind: p.previousToken().kind, value: p.previousToken().value)
  elif p.doesMatch(LeftParen):
    let expre = p.expression()
    p.expect(RightParen, "Expected ')'")
    return GroupingExpr(expre)

proc unary(p: var Parser): Expr =
  if p.doesMatch(Bang, Minus):
    return UnaryExpr(operator: p.previousToken(), right: p.unary())
  return p.primary()

proc factor(p: var Parser): Expr = 
  var expre: Expr = p.unary()
  while p.doesMatch(Slash, Star):
    expre = BinaryExpr(left: expre, operator: p.previousToken(), right: p.unary())

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

proc expression(p: var Parser): Expr = return p.equality()