#
# node.nim
# SLAP
#
# Created by Nobuharu Shimazu on 2/15/2022
# 

import token

# ----------------- Expressions ---------------------
type
  Expr* = ref object of RootObj

  BinaryExpr* = ref object of Expr
    left*: Expr
    operator*: Token
    right*: Expr

  GroupingExpr* = ref object of Expr
    expression*: Expr

  UnaryExpr* = ref object of Expr
    operator*: Token
    right*: Expr

  LiteralExpr* = ref object of Expr
    kind*: TokenType
    value*: string

  LogicalExpr* = ref object of Expr
    left*: Expr
    operator*: Token
    right*: Expr

  VariableExpr* = ref object of Expr
    name*: Token

  AssignExpr* = ref object of Expr
    name*: Token
    value*: Expr

  CallExpr* = ref object of Expr
    callee*: Expr
    paren*: Token
    arguments*: seq[Expr]

  GetExpr* = ref object of Expr
    instance*: Expr
    name*: Token

  SetExpr* = ref object of Expr
    instance*: Expr
    name*: Token
    value*: Expr

  SuperExpr* = ref object of Expr
    keyword*: Token
    class_method*: Token

  SelfExpr* = ref object of Expr
    keyword*: Token

