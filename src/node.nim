#
# node.nim
# SLAP
#
# Created by Nobuharu Shimazu on 2/15/2022
# 

import token
import hashes

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

  MapLiteralExpr* = ref object of Expr
    keys*: seq[Expr]
    values*: seq[Expr]
    keyword*: Token
  
  LogicalExpr* = ref object of Expr
    left*: Expr
    operator*: Token
    right*: Expr

  VariableExpr* = ref object of Expr
    name*: Token
  
  ListOrMapVariableExpr* = ref object of Expr
    variable*: Expr
    indexOrKey*: Expr
    token*: Token

  AssignExpr* = ref object of Expr
    name*: Token
    value*: Expr

  ListOrMapAssignExpr* = ref object of Expr
    variable*: Expr
    indexOrKey*: Expr
    value*: Expr
    token*: Token

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

  FuncExpr* = ref object of Expr
    parameters*: seq[FuncArg]
    body*: seq[Stmt]

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
    function*: FuncExpr
  
  ReturnStmt* = ref object of Stmt
    keyword*: Token
    value*: Expr

  BreakStmt* = ref object of Stmt

  ImportStmt* = ref object of Stmt
    name*: Expr
    keyword*: Token
    imports*: seq[Hash]

  ContinueStmt* = ref object of Stmt
    
  ClassStmt* = ref object of Stmt
    name*: Token
    superclass*: VariableExpr
    methods*: seq[FuncStmt]
    classMethods*: seq[FuncStmt]
  
# ----------------- Non-nodes ---------------------
  FuncArg* = ref object of RootObj

  DefaultValued* = ref object of FuncArg
    paramName*: Token
    default*: Expr
  
  RequiredArg* = ref object of FuncArg
    paramName*: Token

  RestArg* = ref object of FuncArg
    paramName*: Token