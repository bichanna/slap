#
# interpreter.nim
# SLAP
#
# Created by Nobuharu Shimazu on 2/16/2022
#

import error, node, token, slaptype, env, exception
import strutils

type
  # Interpreter takes in an abstract syntax tree and executes
  Interpreter* = object
    error*: Error
    env*: Environment
    globals*: Environment
  
  FuncType* = ref object of BaseType
    call*: proc (self: var Interpreter, args: seq[BaseType]): BaseType
    arity*: proc (): int
  
  Function* = ref object of FuncType
    declaration*: FuncStmt
    closure*: Environment
  
const RuntimeError = "RuntimeError"

proc executeBlock(self: var Interpreter, statements: seq[Stmt], environment: Environment)

proc newInterpreter*(errorObj: Error): Interpreter =
  var globals = newEnv(errorObj)
  globals.define("writeln", FuncType(
    arity: proc(): int = 1,
    call: proc(self: var Interpreter, args: seq[BaseType]): BaseType =
      echo(args[0])
      return newNull()
  ))
  globals.define("write", FuncType(
    arity: proc(): int = 1,
    call: proc(self: var Interpreter, args: seq[BaseType]): BaseType =
      stdout.write(args[0])
      return newNull()
  ))
  return Interpreter(error: errorObj, env: globals, globals: globals)

proc newFunction*(declaration: FuncStmt, closure: Environment): Function =
  var fun = Function()
  fun.declaration = declaration
  fun.closure = closure
  fun.arity = proc(): int = fun.declaration.parameters.len
  fun.call = proc(self: var Interpreter, args: seq[BaseType]): BaseType = 
    var environment = newEnv(self.error, closure)
    for i in 0 ..< fun.declaration.parameters.len:
      environment.define(fun.declaration.parameters[i].value, args[i])
    try:
      self.executeBlock(declaration.body, environment)
    except ReturnException as rx: return rx.value
    return newNull()
  return fun

# ----------------------------------------------------------------------

# forward declarations for helper functions
proc isTruthy(self: var Interpreter, obj: BaseType): bool
proc doesEqual(self: var Interpreter, left: BaseType, right: BaseType): bool
proc `$`(obj: BaseType): string

# --------------------------- EXPRESSIONS ------------------------------

method eval(self: var Interpreter, expre: Expr): BaseType {.base.} = discard

method eval(self: var Interpreter, expre: LiteralExpr): BaseType =
  case expre.kind
  of String: return newString(expre.value)
  of Int: return newInt(parseInt(expre.value))
  of Float: return newFloat(parseFloat(expre.value))
  of True: return newBool(true)
  of False: return newBool(false)
  of Null: return newNull()
  else: discard

# eval GroupingExpr (just for making it easier to search using Command+F)
method eval(self: var Interpreter, expre: GroupingExpr): BaseType =
  return self.eval(expre.expression)

# eval UnaryExpr
method eval(self: var Interpreter, expre: UnaryExpr): BaseType =
  let right: BaseType = self.eval(expre.right)

  case expre.operator.kind
  of Minus:
    if right of SlapInt or right of SlapFloat:  
      if right of SlapInt: return newInt(-SlapInt(right).value)
      elif right of SlapFloat: return newFloat(-SlapFloat(right).value)
    else:
      error(self.error, expre.operator.line, RuntimeError, "All operands must be either string or int and float")
  of Bang:
    return newBool(self.isTruthy(right))
  else:
    discard

# eval VariableExpr
method eval(self: var Interpreter, expre: VariableExpr): BaseType = return self.env.get(expre.name)

# eval AssignExpr
method eval(self: var Interpreter, expre: AssignExpr): BaseType =
  let value = self.eval(expre.value)
  self.env.assign(expre.name, value)
  return value

# eval LogicalExpr
method eval(self: var Interpreter, expre: LogicalExpr): BaseType =
  let left = self.eval(expre.left)
  if expre.operator.kind == Or:
    if self.isTruthy(left): return left
  else:
    if not self.isTruthy(left): return left
  return self.eval(expre.right)

# eval CallExpr
method eval(self: var Interpreter, expre: CallExpr): BaseType =
  let callee = self.eval(expre.callee)
  var arguments: seq[BaseType]
  for arg in expre.arguments: arguments.add(self.eval(arg))
  if not (callee of FuncType):
    error(self.error, expre.paren, RuntimeError, "Can only call classes and functions")
  let function = FuncType(callee)
  if arguments.len != function.arity():
    error(self.error, expre.paren, RuntimeError, "Expected " & $function.arity() & " arguments but got " & $arguments.len)
  return function.call(self, arguments)

# eval BinaryExpr
method eval(self: var Interpreter, expre: BinaryExpr): BaseType =
  var left = self.eval(expre.left)
  var right = self.eval(expre.right)

  case expre.operator.kind
    of Plus: # allows string concatenation and addition
      if left of SlapFloat and right of SlapFloat:
        return newFloat(SlapFloat(left).value + SlapFloat(right).value)
      elif left of SlapFloat and right of SlapInt:
        return newFloat(SlapFloat(left).value + float(SlapInt(right).value))
      elif left of SlapInt and right of SlapFloat:
        return newFloat(float(SlapInt(left).value) + SlapFloat(right).value)
      elif left of SlapInt and right of SlapInt:
        return newInt(SlapInt(left).value + SlapInt(right).value)
      elif left of SlapString and right of SlapString:
        return newString(SlapString(left).value & SlapString(right).value)
      else:
        error(self.error, expre.operator.line, RuntimeError, "All operands must be either string or int and float")
    of Minus:
      if left of SlapFloat and right of SlapFloat:
        return newFloat(SlapFloat(left).value - SlapFloat(right).value)
      elif left of SlapFloat and right of SlapInt:
        return newFloat(SlapFloat(left).value - float(SlapInt(right).value))
      elif left of SlapInt and right of SlapFloat:
        return newFloat(float(SlapInt(left).value) - SlapFloat(right).value)
      elif left of SlapInt and right of SlapInt:
        return newInt(SlapInt(left).value - SlapInt(right).value)
      else:
        error(self.error, expre.operator.line, RuntimeError, "All operands must be either string or int and float")
    of Slash: # division always returns a flost
      if left of SlapFloat and right of SlapFloat:
        if SlapFloat(right).value == 0:
          error(self.error, expre.operator.line, RuntimeError, "Cannot divide by 0")
        else:
          return newFloat(SlapFloat(left).value / SlapFloat(right).value)
      elif left of SlapFloat and right of SlapInt:
        if SlapInt(right).value == 0:
          error(self.error, expre.operator.line, RuntimeError, "Cannot divide by 0")
        else:
          return newFloat(SlapFloat(left).value / float(SlapInt(right).value))
      elif left of SlapInt and right of SlapFloat:
        if SlapFloat(right).value == 0:
          error(self.error, expre.operator.line, RuntimeError, "Cannot divide by 0")
        else:
          return newFloat(float(SlapInt(left).value) / SlapFloat(right).value)
      elif left of SlapInt and right of SlapInt:
        if SlapInt(right).value == 0:
          error(self.error, expre.operator.line, RuntimeError, "Cannot divide by 0")
        else:
          return newFloat(float(SlapInt(left).value) / float(SlapInt(right).value))
      else:
        error(self.error, expre.operator.line, RuntimeError, "All operands must be either int or float")
    of Star:
      if left of SlapFloat and right of SlapFloat:
        return newFloat(SlapFloat(left).value * SlapFloat(right).value)
      elif left of SlapFloat and right of SlapInt:
        return newFloat(SlapFloat(left).value * float(SlapInt(right).value))
      elif left of SlapInt and right of SlapFloat:
        return newFloat(float(SlapInt(left).value) * SlapFloat(right).value)
      elif left of SlapInt and right of SlapInt:
        return newInt(SlapInt(left).value * SlapInt(right).value)
      else:
        error(self.error, expre.operator.line, RuntimeError, "All operands must be either int or float")
    of Modulo:
      if left of SlapInt and right of SlapInt:
        return newInt(SlapInt(left).value mod SlapInt(right).value)
      else:
        error(self.error, expre.operator.line, RuntimeError, "All operands must be int")
    # Comparison Operators
    of Greater:
      if left of SlapFloat and right of SlapFloat:
        return newBool(SlapFloat(left).value > SlapFloat(right).value)
      elif left of SlapFloat and right of SlapInt:
        return newBool(SlapFloat(left).value > float(SlapInt(right).value))
      elif left of SlapInt and right of SlapFloat:
        return newBool(float(SlapInt(left).value) > SlapFloat(right).value)
      elif left of SlapInt and right of SlapInt:
        return newBool(SlapInt(left).value > SlapInt(right).value)
      else:
        error(self.error, expre.operator.line, RuntimeError, "All operands must be either int or float")
    of GreaterEqual:
      if left of SlapFloat and right of SlapFloat:
        return newBool(SlapFloat(left).value >= SlapFloat(right).value)
      elif left of SlapFloat and right of SlapInt:
        return newBool(SlapFloat(left).value >= float(SlapInt(right).value))
      elif left of SlapInt and right of SlapFloat:
        return newBool(float(SlapInt(left).value) >= SlapFloat(right).value)
      elif left of SlapInt and right of SlapInt:
        return newBool(SlapInt(left).value >= SlapInt(right).value)
      else:
        error(self.error, expre.operator.line, RuntimeError, "All operands must be either int or float")
    of Less:
      if left of SlapFloat and right of SlapFloat:
        return newBool(SlapFloat(left).value < SlapFloat(right).value)
      elif left of SlapFloat and right of SlapInt:
        return newBool(SlapFloat(left).value < float(SlapInt(right).value))
      elif left of SlapInt and right of SlapFloat:
        return newBool(float(SlapInt(left).value) < SlapFloat(right).value)
      elif left of SlapInt and right of SlapInt:
        return newBool(SlapInt(left).value < SlapInt(right).value)
      else:
        error(self.error, expre.operator.line, RuntimeError, "All operands must be either int or float")
    of LessEqual:
      if left of SlapFloat and right of SlapFloat:
        return newBool(SlapFloat(left).value <= SlapFloat(right).value)
      elif left of SlapFloat and right of SlapInt:
        return newBool(SlapFloat(left).value <= float(SlapInt(right).value))
      elif left of SlapInt and right of SlapFloat:
        return newBool(float(SlapInt(left).value) <= SlapFloat(right).value)
      elif left of SlapInt and right of SlapInt:
        return newBool(SlapInt(left).value <= SlapInt(right).value)
      else:
        error(self.error, expre.operator.line, RuntimeError, "All operands must be either int or float")
    of BangEqual: return newBool(not self.doesEqual(left, right))
    of EqualEqual: return newBool(self.doesEqual(left, right))
    else:
      discard

# --------------------------- STATEMENTS -------------------------------

method eval(self: var Interpreter, statement: Stmt) {.base.} = discard

method eval(self: var Interpreter, statement: ExprStmt) = discard self.eval(statement.expression)

method eval(self: var Interpreter, statement: VariableStmt) = 
  var value: BaseType = newNull() # defaults to null
  if not statement.init.isNil: value = self.eval(statement.init)
  self.env.define(statement.name.value, value)

method eval(self: var Interpreter, statement: FuncStmt) =
  let function = newFunction(statement, self.env)
  self.env.define(statement.name.value, function)

proc executeBlock(self: var Interpreter, statements: seq[Stmt], environment: Environment) =
  let previous = self.env
  try:
    self.env = environment
    for i in statements:
      self.eval(i)
  finally:
    self.env = previous

method eval(self: var Interpreter, statement: BlockStmt) = self.executeBlock(statement.statements, newEnv(self.error, self.env))

method eval(self: var Interpreter, statement: ReturnStmt) =
  var value: BaseType
  if not statement.value.isNil: value = self.eval(statement.value)
  raise ReturnException(value: value)

method eval(self: var Interpreter, statement: WhileStmt) =
  while self.isTruthy(self.eval(statement.condition)):
    self.eval(statement.body)

method eval(self: var Interpreter, statement: IfStmt) =
  if self.isTruthy(self.eval(statement.condition)):
    self.eval(statement.thenBranch)
  elif not statement.elseBranch.isNil:
    self.eval(statement.elseBranch)

# ----------------------------------------------------------------------

proc interpret*(self: var Interpreter, statements: seq[Stmt]) =
  for s in statements:
    try:
      self.eval(s)
    except ReturnException as rx:
      error(self.error, -2, "RuntimeError", "Return statement can only be used inside functions\nvalue: " & $rx.value)

# ---------------------------- HELPERS ---------------------------------

proc isTruthy(self: var Interpreter, obj: BaseType): bool =
  if obj of SlapNull: return false
  if obj of SlapBool: return SlapBool(obj).value
  else: return true

proc doesEqual(self: var Interpreter, left: BaseType, right: BaseType): bool = 
  if left of SlapNull and right of SlapNull: return true
  elif left of SlapNull: return false
  elif left of SlapInt and right of SlapInt: return SlapInt(left).value == SlapInt(right).value
  elif left of SlapInt and right of SlapFloat: return float(SlapInt(left).value) == SlapFloat(right).value
  elif left of SlapFloat and right of SlapFloat: return SlapFloat(left).value == SlapFloat(right).value
  elif left of SlapFloat and right of SlapInt: return SlapFloat(left).value == float(SlapInt(right).value)
  elif left of SlapString and right of SlapString: return SlapString(left).value == SlapString(right).value
  # I will add for classes, functions, etc.
  else: return false

proc `$`(obj: BaseType): string =
  if obj of SlapNull: return "null"
  elif obj of SlapInt: return $SlapInt(obj).value
  elif obj of SlapFloat: return $SlapFloat(obj).value
  elif obj of SlapString: return SlapString(obj).value
  elif obj of SlapBool: return $SlapBool(obj).value
  elif obj of Function: return "<function " & Function(obj).declaration.name.value & ">"
  
  # hopefully unreachable
  return "unknown type"