#
# resolver.nim
# SLAP
#
# Created by Nobuharu Shimazu on 2/22/2022
#

import interpreter, node, token, error, interpreterObj
import tables

type
  Resolver* = ref object of RootObj
    interpreter*: Interpreter
    error*: Error
    scopes: seq[Table[string, bool]]
    currentFunction: FunctionType
    currentClass: ClassType
  
  FunctionType = enum
    NONE, FUNCTION, METHOD, INITIALIZER

  ClassType = enum
    CNONE, CLASS

proc newResolver*(interpreter: Interpreter, errorObj: Error): Resolver =
  return Resolver(interpreter: interpreter, error: errorObj, currentFunction: NONE, currentClass: CNONE)

# ----------------------------------------------------------------------

proc beginScope(self: var Resolver)
proc endScope(self: var Resolver)
proc declare(self: var Resolver, name: Token)
proc define(self: var Resolver, name: Token)
proc resolveLocal(self: var Resolver, expre: Expr, name: Token)
proc resolveFunction(self: var Resolver, function: FuncExpr, functype: FunctionType)

# ----------------------------------------------------------------------

method resolve(self: var Resolver, expre: Expr) {.base, locks: "unknown".} = discard
method resolve(self: var Resolver, statement: Stmt) {.base, locks: "unknown".} = discard

method resolve*(self: var Resolver, statements: seq[Stmt]) =
  for statement in statements:
    self.resolve(statement)

method resolve(self: var Resolver, statement: BlockStmt) =
  self.beginScope()
  self.resolve(statement.statements)
  self.endScope()

method resolve(self: var Resolver, statement: VariableStmt) =
  self.declare(statement.name)
  if not statement.init.isNil: self.resolve(statement.init)
  self.define(statement.name)

method resolve(self: var Resolver, expre: VariableExpr) =
  if not (self.scopes.len == 0) and self.scopes[self.scopes.len-1].getOrDefault(expre.name.value, true) == false:
    error(self.error, expre.name, "SyntaxError", "Cannot read local variable in its own initializer")
  self.resolveLocal(expre, expre.name)

method resolve(self: var Resolver, expre: ListOrMapVariableExpr) =
  self.resolve(expre.indexOrKey)
  if not (self.scopes.len == 0) and self.scopes[self.scopes.len-1].getOrDefault(expre.name.value, true) == false:
    error(self.error, expre.name, "SyntaxError", "Cannot read local variable in its own initializer")
  self.resolveLocal(expre, expre.name)

method resolve(self: var Resolver, expre: AssignExpr) =
  self.resolve(expre.value)
  self.resolveLocal(expre, expre.name)

method resolve(self: var Resolver, expre: ListOrMapAssignExpr) =
  self.resolve(expre.value)
  self.resolve(expre.indexOrKey)
  self.resolveLocal(expre, expre.name)

method resolve(self: var Resolver, statement: FuncStmt) =
  self.declare(statement.name)
  self.define(statement.name)
  self.resolveFunction(statement.function, FUNCTION)

method resolve(self: var Resolver, expre: FuncExpr) =
  self.resolveFunction(expre, FUNCTION)

method resolve(self: var Resolver, statement: ExprStmt) = self.resolve(statement.expression)

method resolve(self: var Resolver, statement: ElifStmt) =
  self.resolve(statement.condition)
  self.resolve(statement.thenBranch)

method resolve(self: var Resolver, statement: IfStmt) =
  self.resolve(statement.condition)
  self.resolve(statement.thenBranch)
  if not statement.elifBranches.len != 0:
    for i in statement.elifBranches:
      self.resolve(i)
  if not statement.elseBranch.isNil: self.resolve(statement.elseBranch)

method resolve(self: var Resolver, statement: ReturnStmt) =
  if self.currentFunction == NONE: error(self.error, statement.keyword, "SyntaxError", "Cannot return from top-level code")
  if not statement.value.isNil:
    if self.currentFunction == INITIALIZER:
      error(self.error, statement.keyword, "SyntaxError", "Cannot return a value from an initializer")
    self.resolve(statement.value)

method resolve(self: var Resolver, statement: WhileStmt) =
  self.resolve(statement.condition)
  self.resolve(statement.body)

method resolve(self: var Resolver, expre: BinaryExpr) =
  self.resolve(expre.left)
  self.resolve(expre.right)

method resolve(self: var Resolver, expre: CallExpr) =
  self.resolve(expre.callee)
  for argument in expre.arguments: self.resolve(argument)

method resolve(self: var Resolver, expre: GroupingExpr) = self.resolve(expre.expression)

method resolve(self: var Resolver, expre: LiteralExpr) = discard

method resolve(self: var Resolver, expre: LogicalExpr) =
  self.resolve(expre.left)
  self.resolve(expre.right)

method resolve(self: var Resolver, statement: ClassStmt) = 
  let enclosingClass = self.currentClass
  self.currentClass = CLASS
  self.declare(statement.name)
  self.define(statement.name)

  self.beginScope()
  self.scopes[self.scopes.len-1]["self"] = true
  for m in statement.methods:
    var declaration = METHOD
    if m.name.value == "new": declaration = INITIALIZER
    self.resolveFunction(m.function, declaration)
  for m in statement.classMethods:
    self.beginScope()
    self.scopes[self.scopes.len-1]["self"] = true
    self.resolveFunction(m.function, METHOD)
    self.endScope()
  self.endScope()
  self.currentClass = enclosingClass;

method resolve(self: var Resolver, expre: UnaryExpr) = self.resolve(expre.right)

method resolve(self: var Resolver, expre: GetExpr) = self.resolve(expre.instance)

method resolve(self: var Resolver, expre: SetExpr) =
  self.resolve(expre.value)
  self.resolve(expre.instance)

method resolve(self: var Resolver, expre: SelfExpr) =
  if self.currentClass == CNONE:
    error(self.error, expre.keyword, "SyntaxError", "Cannot use 'self' or '&' outside of a class")
  self.resolveLocal(expre, expre.keyword)

method resolve(self: var Resolver, expre: ListLiteralExpr) =
  for value in expre.values:
    self.resolve(value)

method resolve(self: var Resolver, expre: MapLiteralExpr) =
  for k in expre.keys:
    self.resolve(k)
  for v in expre.values:
    self.resolve(v)

# ---------------------------- HELPERS ---------------------------------

proc beginScope(self: var Resolver) = self.scopes.add(initTable[string, bool]())

proc endScope(self: var Resolver) = discard self.scopes.pop()

proc declare(self: var Resolver, name: Token) =
  if self.scopes.len == 0: return
  elif self.scopes[self.scopes.len-1].contains(name.value):
    error(self.error, name, "SyntaxError", "Variable with this name is already declared in this scope")
  else: self.scopes[self.scopes.len-1][name.value] = false

proc define(self: var Resolver, name: Token) =
  if self.scopes.len == 0: return
  elif self.scopes[self.scopes.len-1].contains(name.value):
    self.scopes[self.scopes.len-1].del(name.value)
  self.scopes[self.scopes.len-1][name.value] = true

proc resolveLocal(self: var Resolver, expre: Expr, name: Token) =
  for i in countdown(self.scopes.len-1, 0):
    if self.scopes[i].contains(name.value):
      self.interpreter.resolve(expre, self.scopes.len - 1 - i)
      return

proc resolveFunction(self: var Resolver, function: FuncExpr, functype: FunctionType) =
  let enclosingFunction = self.currentFunction
  self.currentFunction = functype
  self.beginScope()
  for param in function.parameters:
    self.declare(param)
    self.define(param)
  self.resolve(function.body)
  self.endScope()
  self.currentFunction = enclosingFunction