#
# interpreter.nim
# SLAP
#
# Created by Nobuharu Shimazu on 2/16/2022
#

import error, node, token, slaptype, env, exception, interpreterObj
import strutils, tables

proc `$`*(obj: BaseType): string
  
const RuntimeError = "RuntimeError"

proc executeBlock(self: var Interpreter, statements: seq[Stmt], environment: Environment)

proc newListInstance(init: SlapList): ListInstance

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
  globals.define("List", FuncType(
    arity: proc(): int = 1,
    call: proc(self: var Interpreter, args: seq[BaseType]): BaseType =
      return newListInstance(SlapList(args[0]))
  ))
  return Interpreter(error: errorObj, env: globals, globals: globals, locals: initTable[int, int]())

# ----------------------------- FUNCTIONS & CLASSES ----------------------------------

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
  if not ct.superclass.isNil: return ct.superclass.findMethod(name)
  return nil

proc `bind`(self: Function, instance: ClassInstance, i: Interpreter): Function =
  var env = newEnv(i.error, self.closure)
  env.define("self", instance)
  return newFunction(self.declaration, env, self.isInitFunc)

proc newClassInstance(class: ClassType): ClassInstance = 
  var instance = ClassInstance(class: class, fields: initTable[string, BaseType]())
  return instance

proc newClass(metaclass: ClassType, superclass: ClassType, name: string, methods: Table[string, Function]): ClassType =
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
  class.superclass = superclass
  return class

proc get(ci: ClassInstance, name: Token, i: Interpreter): BaseType =
  if not (ci of ListInstance):
    if ci.fields.hasKey(name.value): return ci.fields[name.value]
    let m = findMethod(ci.class, name.value)
    if not m.isNil: return m.`bind`(ci, i)
    error(i.error, name.line, RuntimeError, "Property '" & name.value & "' is not defined")
  else:
    var li = ListInstance(ci)
    if name.value == "get":
      return FuncType(
        arity: proc(): int = 1,
        call: proc(self: var Interpreter, args: seq[BaseType]): BaseType =
          if not (args[0] of SlapInt): error(i.error, name.line, RuntimeError, "list indices must be integers")
          return li.elements[SlapInt(args[0]).value]
      )
    elif name.value == "append":
      return FuncType(
        arity: proc(): int = 1,
        call: proc(self: var Interpreter, args: seq[BaseType]): BaseType =
          li.elements.add(args[0])
          return newNull()
      )
    elif name.value == "pop":
      return FuncType(
        arity: proc(): int = 0,
        call: proc(self: var Interpreter, args: seq[BaseType]): BaseType =
          return li.elements.pop()
      )
    elif name.value == "insert":
      return FuncType(
        arity: proc(): int = 2,
        call: proc(self: var Interpreter, args: seq[BaseType]): BaseType =
          if not (args[0] of SlapInt): error(i.error, name, RuntimeError, "index must be an integer")
          li.elements.insert(args[1], SlapInt(args[0]).value)
          return newNull()
      )
    elif name.value == "set":
      return FuncType(
        arity: proc(): int = 2,
        call: proc(self: var Interpreter, args: seq[BaseType]): BaseType =
          if not (args[0] of SlapInt): error(i.error, name, RuntimeError, "index must be an integer")
          if SlapInt(args[0]).value >= li.elements.len: error(i.error, name, RuntimeError, "index out of range")
          li.elements[SlapInt(args[0]).value] = args[1]
          return newNull()
      )
    elif name.value == "len":
      return newInt(li.elements.len)
    else:
      error(i.error, name.line, RuntimeError, "Property '" & name.value & "' is not defined")

proc set(ci: ClassInstance, name: Token, value: BaseType) = ci.fields[name.value] = value

# ------------------------------- LIST ---------------------------------

proc newListInstance(init: SlapList): ListInstance =
  var elements: seq[BaseType]
  for i in init.values:
    elements.add(i)
  return ListInstance(elements: elements)

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

# eval SuperExpr
method eval(self: var Interpreter, expre: SuperExpr): BaseType =
  let i = self.exprSeqForLocals.find(expre)
  if i != -1:
    let distance = self.locals.getOrDefault(i, -1)
    if distance != -1:
      let superclass = ClassType(self.env.getAt(distance, "super"))
      let obj = ClassInstance(self.env.getAt(distance-1, "self"))
      let m = superclass.findMethod(expre.classMethod.value)
      if m.isNil:
        error(self.error, expre.classMethod, RuntimeError, "'" & expre.classMethod.value & "' is not defined")
      return m.`bind`(obj, self)

method eval(self: var Interpreter, expre: ListLiteralExpr): BaseType =
  var values: seq[BaseType]
  for value in expre.values:
    values.add(self.eval(value))
  return newList(values)

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
      elif left of SlapString and right of SlapInt:
        var str = ""
        for i in 0 ..< SlapInt(right).value: str &= SlapString(left).value
        return newString(str)
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
  except OverflowDefect:
    error(self.error, statement.keyword, RuntimeError, "Over- or underflow")
  # just ignore
  except BreakException: return

method eval(self: var Interpreter, statement: IfStmt) =
  var done = false
  if self.isTruthy(self.eval(statement.condition)):
    self.eval(statement.thenBranch)
    done = true
  elif statement.elifBranches.len != 0:
    for each in statement.elifBranches:
      if self.isTruthy(self.eval(each.condition)):
        self.eval(each.thenBranch)
        done = true
        break
  if not statement.elseBranch.isNil and done == false:
    self.eval(statement.elseBranch)

method eval(self: var Interpreter, statement: BreakStmt) = raise BreakException()

method eval(self: var Interpreter, statement: ClassStmt) =
  var superclass: BaseType
  if not statement.superclass.isNil:
    superclass = self.eval(statement.superclass)
    if not (superclass of ClassType):
      error(self.error, statement.superclass.name, RuntimeError, "Superclass must be a class")
    
  self.env.define(statement.name.value, newNull())
  var classMethods = initTable[string, Function]()
  for m in statement.classMethods:
    let fun = newFunction(m, self.env, false)
    classMethods[m.name.value] = fun
  let metaclass = newClass(nil, nil, statement.name.value & " metaclass", classMethods)

  if not statement.superclass.isNil:
    self.env = newEnv(self.error, self.env)
    self.env.define("super", superclass)

  var methods = initTable[string, Function]()
  for m in statement.methods:
    let function = newFunction(m, self.env, m.name.value == "new")
    methods[m.name.value] = function
  let class = newClass(metaclass, ClassType(superclass), statement.name.value, methods)

  if not superclass.isNil: self.env = self.env.enclosing

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
  elif obj of SlapList: return $SlapList(obj).values
  elif obj of Function: return "<fn " & Function(obj).declaration.name.value & ">"
  elif obj of FuncType: return "<native fn>"
  elif obj of ClassType: return "<class " & ClassType(obj).name & ">"
  elif obj of ListInstance: return $ListInstance(obj).elements
  elif obj of ClassInstance: return "<instance " & ClassInstance(obj).class.name & ">"
  
  # hopefully unreachable
  return "unknown type"