#
# node.nim
# SLAP
#
# Created by Nobuharu Shimazu on 2/15/2022
# 

import token

var isRepl*: bool = false

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
  
  ListLiteralExpr* = ref object of Expr
    values*: seq[Expr]
    keyword*: Token

  LogicalExpr* = ref object of Expr
    left*: Expr
    operator*: Token
    right*: Expr

  VariableExpr* = ref object of Expr
    name*: Token
  
  ListVariableExpr* = ref object of Expr
    name*: Token
    index*: Expr

  AssignExpr* = ref object of Expr
    name*: Token
    value*: Expr

  ListAssignExpr* = ref object of Expr
    name*: Token
    index*: Expr
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
    classMethod*: Token

  SelfExpr* = ref object of Expr
    keyword*: Token

# ----------------- Statements ---------------------
  Stmt* = ref object of RootObj

  ExprStmt* = ref object of Stmt
    expression*: Expr
  
  VariableStmt* = ref object of Stmt
    name*: Token
    init*: Expr

  IfStmt* = ref object of Stmt
    condition*: Expr
    thenBranch*: Stmt
    elifBranches*: seq[ElifStmt]
    elseBranch*: Stmt

  ElifStmt* = ref object of Stmt
    condition*: Expr
    thenBranch*: Stmt
  
  BlockStmt* = ref object of Stmt
    statements*: seq[Stmt]

  WhileStmt* = ref object of Stmt
    condition*: Expr
    body*: Stmt
    keyword*: Token
  
  FuncStmt* = ref object of Stmt
    name*: Token
    parameters*: seq[Token]
    body*: seq[Stmt]
  
  ReturnStmt* = ref object of Stmt
    keyword*: Token
    value*: Expr

  BreakStmt* = ref object of Stmt
    
  ClassStmt* = ref object of Stmt
    name*: Token
    superclass*: VariableExpr
    methods*: seq[FuncStmt]
    classMethods*: seq[FuncStmt]
  