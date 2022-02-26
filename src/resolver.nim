#
# resolver.nim
# SLAP
#
# Created by Nobuharu Shimazu on 2/22/2022
#

import interpreter, node, token, error
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
    CNONE, CLASS, SUBCLASS

proc newResolver*(interpreter: Interpreter, errorObj: Error): Resolver =
  return Resolver(interpreter: interpreter, error: errorObj, currentFunction: NONE, currentClass: CNONE)

# ----------------------------------------------------------------------

proc beginScope(self: var Resolver)
proc endScope(self: var Resolver)
proc declare(self: var Resolver, name: Token)
proc define(self: var Resolver, name: Token)
proc resolveLocal(self: var Resolver, expre: Expr, name: Token)
proc resolveFunction(self: var Resolver, function: FuncStmt, functype: FunctionType)

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

method resolve(self: var Resolver, expre: AssignExpr) =
  self.resolve(expre.value)
  self.resolveLocal(expre, expre.name)

method resolve(self: var Resolver, statement: FuncStmt) =
  self.declare(statement.name)
  self.define(statement.name)
  self.resolveFunction(statement, FUNCTION)

method resolve(self: var Resolver, statement: ExprStmt) = self.resolve(statement.expression)

method resolve(self: var Resolver, statement: IfStmt) =
  self.resolve(statement.condition)
  self.resolve(statement.thenBranch)
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
#     ClassType enclosingClass = currentClass;
#     currentClass = ClassType.CLASS;
#     declare(stmt.name);
#     define(stmt.name);
#     if (stmt.superclass != null && stmt.name.lexeme.equals(stmt.superclass.name.lexeme)) {
#       Lox.error(stmt.superclass.name,
#           "A class can't inherit from itself.");
#     }
#     if (stmt.superclass != null) {
#       currentClass = ClassType.SUBCLASS;
#       resolve(stmt.superclass);
#     }
#     if (stmt.superclass != null) {
#       beginScope();
#       scopes.peek().put("super", true);
#     }
#     beginScope();
#     scopes.peek().put("this", true);
#     for (Stmt.Function method : stmt.methods) {
#       FunctionType declaration = FunctionType.METHOD;
#       if (method.name.lexeme.equals("init")) {
#         declaration = FunctionType.INITIALIZER;
#       }
#       resolveFunction(method, declaration); // [local]
#     }
#     endScope();
#     if (stmt.superclass != null) endScope();
#     currentClass = enclosingClass;
#     return null;
  let enclosingClass = self.currentClass
  self.currentClass = CLASS
  self.declare(statement.name)
  self.define(statement.name)

  # a case like this: `class SomeClass <- SomeClass {}`
  if not statement.superclass.isNil and statement.name.value == statement.superclass.name.value:
    error(self.error, statement.superclass.name, "SyntaxError", "A class cannot inherit from itself")

  if not statement.superclass.isNil:
    self.resolve(statement.superclass)
  
  if not statement.superclass.isNil:
    self.beginScope()
    self.scopes[self.scopes.len-1]["super"] = true

  self.beginScope()
  self.scopes[self.scopes.len-1]["self"] = true
  for m in statement.methods:
    var declaration = METHOD
    if m.name.value == "new": declaration = INITIALIZER
    self.resolveFunction(m, declaration)
  
  for m in statement.classMethods:
    self.beginScope()
    self.scopes[self.scopes.len-1]["self"] = true
    self.resolveFunction(m, METHOD)
    self.endScope()
  self.endScope()

  if not statement.superclass.isNil: self.endScope()

  self.currentClass = enclosingClass;

method resolve(self: var Resolver, expre: UnaryExpr) = self.resolve(expre.right)

method resolve(self: var Resolver, expre: GetExpr) = self.resolve(expre.instance)

method resolve(self: var Resolver, expre: SuperExpr) = self.resolveLocal(expre, expre.keyword)

method resolve(self: var Resolver, expre: SetExpr) =
  self.resolve(expre.value)
  self.resolve(expre.instance)

method resolve(self: var Resolver, expre: SelfExpr) =
  if self.currentClass == CNONE:
    error(self.error, expre.keyword, "SyntaxError", "Cannot use 'self' or '&' outside of a class")
  self.resolveLocal(expre, expre.keyword)

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

proc resolveFunction(self: var Resolver, function: FuncStmt, functype: FunctionType) =
  let enclosingFunction = self.currentFunction
  self.currentFunction = functype
  self.beginScope()
  for param in function.parameters:
    self.declare(param)
    self.define(param)
  self.resolve(function.body)
  self.endScope()
  self.currentFunction = enclosingFunction