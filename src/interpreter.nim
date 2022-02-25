#
# interpreter.nim
# SLAP
#
# Created by Nobuharu Shimazu on 2/16/2022
#

import error, node, token, slaptype, env, exception
import strutils, tables

proc `$`*(obj: BaseType): string

type
  # Interpreter takes in an abstract syntax tree and executes
  Interpreter* = object
    error*: Error
    env*: Environment
    globals*: Environment
    exprSeqForLocals*: seq[Expr]
    locals*: Table[int, int]
  
  FuncType* = ref object of BaseType
    call*: proc (self: var Interpreter, args: seq[BaseType]): BaseType
    arity*: proc (): int
  
  Function* = ref object of FuncType
    isInitFunc*: bool
    declaration*: FuncStmt
    closure*: Environment

  ClassType* = ref object of FuncType
    name*: string
    methods*: Table[string, Function]
    cinstance*: ClassInstance

  ClassInstance* = ref object of BaseType
    class*: ClassType
    fields*: Table[string, BaseType]
  
const RuntimeError = "RuntimeError"

proc executeBlock(self: var Interpreter, statements: seq[Stmt], environment: Environment)

proc newInterpreter*(errorObj: Error): Interpreter =
  var globals = newEnv(errorObj)
  globals.define("writeln", FuncType(
    arity: proc(): int = 1,
    call: proc(self: var Interpreter, args: seq[BaseType]): BaseType =
      stdout.write(args[0], "\n")
      return newNull()
  ))
  globals.define("write", FuncType(
    arity: proc(): int = 1,
    call: proc(self: var Interpreter, args: seq[BaseType]): BaseType =
      stdout.write(args[0])
      return newNull()
  ))
  return Interpreter(error: errorObj, env: globals, globals: globals, locals: initTable[int, int]())

proc newFunction(declaration: FuncStmt, closure: Environment, isInitFunc: bool = false): Function =
  var fun = Function()
  fun.isInitFunc = isInitFunc
  fun.declaration = declaration
  fun.closure = closure
  fun.arity = proc(): int = fun.declaration.parameters.len
  fun.call = proc(self: var Interpreter, args: seq[BaseType]): BaseType = 
    var environment = newEnv(self.error, closure)
    for i in 0 ..< fun.declaration.parameters.len:
      environment.define(fun.declaration.parameters[i].value, args[i])
    try:
      self.executeBlock(declaration.body, environment)
    except ReturnException as rx:
      return rx.value
    if isInitFunc: return fun.closure.getAt(0, "self")
    return newNull()
  return fun

proc findMethod(ct: ClassType, name: string): Function =
  if ct.methods.hasKey(name): return ct.methods[name]
  return nil

proc `bind`(self: Function, instance: ClassInstance, i: Interpreter): Function =
  var env = newEnv(i.error, self.closure)
  env.define("self", instance)
  return newFunction(self.declaration, env, self.isInitFunc)

proc newClassInstance(class: ClassType): ClassInstance = 
  var instance = ClassInstance(class: class, fields: initTable[string, BaseType]())
  return instance

proc newClass(metaclass: ClassType, name: string, methods: Table[string, Function]): ClassType =
  var class = ClassType(name: name)
  class.arity = proc(): int = 
    let init = class.findMethod("new")
    if init.isNil: return 0
    else: return init.arity()
  class.call = proc(self: var Interpreter, args: seq[BaseType]): BaseType = 
    var instance = newClassInstance(class)
    var init = class.methods.getOrDefault("new", nil)
    if not init.isNil: discard `bind`(init, instance, self).call(self, args)
    return instance
  class.methods = methods
  class.cinstance = newClassInstance(metaclass)
  return class

proc get(ci: ClassInstance, name: Token, i: Interpreter): BaseType =
  if ci.fields.hasKey(name.value): return ci.fields[name.value]
  let m = findMethod(ci.class, name.value)
  if not m.isNil: return m.`bind`(ci, i)
  error(i.error, name.line, RuntimeError, "Property '" & name.value & "' is not defined")

proc set(ci: ClassInstance, name: Token, value: BaseType) = ci.fields[name.value] = value

# ----------------------------------------------------------------------

# forward declarations for helper functions
proc isTruthy(self: var Interpreter, obj: BaseType): bool
proc doesEqual(self: var Interpreter, left: BaseType, right: BaseType): bool
proc loopUpVariable(self: var Interpreter, name: Token, expre: Expr): BaseType

# --------------------------- EXPRESSIONS ------------------------------

method eval(self: var Interpreter, expre: Expr): BaseType {.base, locks: "unknown".} = discard

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
method eval(self: var Interpreter, expre: VariableExpr): BaseType =
  return self.loopUpVariable(expre.name, expre)

# eval AssignExpr
method eval(self: var Interpreter, expre: AssignExpr): BaseType =
  let value = self.eval(expre.value)
  var gotIt = false
  let i = self.exprSeqForLocals.find(expre)
  if i != -1:
    let distance = self.locals.getOrDefault(i, -1)
    if distance != -1:
      gotIt = true
      self.env.assignAt(distance, expre.name, value)
  if not gotIt: self.globals.assign(expre.name, value)
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

# eval GetExpr
method eval(self: var Interpreter, expre: GetExpr): BaseType =
  let obj = self.eval(expre.instance)
  if obj of ClassInstance:
    return ClassInstance(obj).get(expre.name, self)
  elif obj of ClassType:
    return ClassType(obj).cinstance.get(expre.name, self)
  error(self.error, expre.name.line, RuntimeError, "Only instances have properties")

# eval SetExpr
method eval(self: var Interpreter, expre: SetExpr): BaseType =
  let instance = self.eval(expre.instance)
  if not (instance of ClassInstance):
    error(self.error, expre.name.line, RuntimeError, "Only instances have fields")
  let value = self.eval(expre.value)
  ClassInstance(instance).set(expre.name, value)
  return value

# eval SelfExpr
method eval(self: var Interpreter, expre: SelfExpr): BaseType = return self.loopUpVariable(expre.keyword, expre)

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

method eval(self: var Interpreter, statement: Stmt) {.base, locks: "unknown".} = discard

method eval(self: var Interpreter, statement: ExprStmt) =
  discard self.eval(statement.expression)

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

method eval(self: var Interpreter, statement: BlockStmt) =
  self.executeBlock(statement.statements, newEnv(self.error, self.env))

method eval(self: var Interpreter, statement: ReturnStmt) =
  var value: BaseType
  if not statement.value.isNil: value = self.eval(statement.value)
  raise ReturnException(value: value)

method eval(self: var Interpreter, statement: WhileStmt) =
  try:
    while self.isTruthy(self.eval(statement.condition)):
      self.eval(statement.body)
  # just ignore
  except BreakException: return

method eval(self: var Interpreter, statement: IfStmt) =
  if self.isTruthy(self.eval(statement.condition)):
    self.eval(statement.thenBranch)
  elif not statement.elseBranch.isNil:
    self.eval(statement.elseBranch)

method eval(self: var Interpreter, statement: BreakStmt) = raise BreakException()

method eval(self: var Interpreter, statement: ClassStmt) =
  self.env.define(statement.name.value, newNull())
  var classMethods = initTable[string, Function]()
  for m in statement.classMethods:
    let fun = newFunction(m, self.env, false)
    classMethods[m.name.value] = fun
  let metaclass = newClass(nil, statement.name.value & " metaclass", classMethods)

  var methods = initTable[string, Function]()
  for m in statement.methods:
    let function = newFunction(m, self.env, m.name.value == "new")
    methods[m.name.value] = function
  let class = newClass(metaclass, statement.name.value, methods)
  self.env.assign(statement.name, class)

# ----------------------------------------------------------------------

proc resolve*(self: var Interpreter, expre: Expr, depth: int) =
  self.exprSeqForLocals.add(expre)
  self.locals[self.exprSeqForLocals.len-1] = depth

proc interpret*(self: var Interpreter, statements: seq[Stmt]) =
  for s in statements:
    self.eval(s)

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
  else: return false

proc loopUpVariable(self: var Interpreter, name: Token, expre: Expr): BaseType = 
  var gotIt = false
  let i = self.exprSeqForLocals.find(expre)
  if i != -1:
    let distance = self.locals.getOrDefault(i, -1)
    if distance != -1:
      gotIt = true
      return self.env.getAt(distance, name.value)
  if not gotIt:
    return self.globals.get(name)

proc `$`*(obj: BaseType): string =
  if obj of SlapNull: return "null"
  elif obj of SlapInt: return $SlapInt(obj).value
  elif obj of SlapFloat: return $SlapFloat(obj).value
  elif obj of SlapString: return SlapString(obj).value
  elif obj of SlapBool: return $SlapBool(obj).value
  elif obj of Function: return "<fn " & Function(obj).declaration.name.value & ">"
  elif obj of FuncType: return "<native fn>"
  elif obj of ClassType: return "<class " & ClassType(obj).name & ">"
  elif obj of ClassInstance: return "<instance " & ClassInstance(obj).class.name & ">"
  
  # hopefully unreachable
  return "unknown type"