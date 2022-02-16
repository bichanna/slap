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

  Binary* = ref object of Expr
    left*: Expr
    operator*: Token
    right*: Expr

  Grouping* = ref object of Expr
    expression*: Expr

  Unary* = ref object of Expr
    operator*: Token
    right*: Expr

  Literal* = ref object of Expr
    kind*: TokenType
    value*: string

  Logical* = ref object of Expr
    left*: Expr
    operator*: Token
    right*: Expr

  Variable* = ref object of Expr
    name*: Token

  Assign* = ref object of Expr
    name*: Token
    value*: Expr

  Call* = ref object of Expr
    callee*: Expr
    paren*: Token
    arguments*: seq[Expr]

  Get* = ref object of Expr
    instance*: Expr
    name*: Token

  Set* = ref object of Expr
    instance*: Expr
    name*: Token
    value*: Expr

  Super* = ref object of Expr
    keyword*: Token
    class_method*: Token

  Self* = ref object of Expr
    keyword*: Token

