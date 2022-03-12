#
# interpreter.nim
# SLAP
#
# Created by Nobuharu Shimazu on 2/16/2022
#

import error, node, token, slaptype, env, exception, interpreterObj, builtin, objhash, lexer, parser
import strutils, tables, sequtils, hashes
  
const
  RuntimeError = "RuntimeError"
  
  libstd = staticRead"../lib/stdlib.slap"
  libstr = staticRead"../lib/strlib.slap"
  libmath = staticRead"../lib/mathlib.slap"

let stdlibs: Table[string, string] = {
    "std": libstd,
    "str": libstr,
    "math": libmath,
  }.toTable


proc executeBlock(self: var Interpreter, statements: seq[Stmt], environment: Environment)

method eval(self: var Interpreter, expre: Expr): BaseType {.base, locks: "unknown".}

proc newInterpreter*(): Interpreter =
  var globals = loadBuildins()
  return Interpreter(env: globals, globals: globals, locals: initTable[Expr, int]())

# ----------------------------- FUNCTIONS & CLASSES ----------------------------------

proc newFunction(name: string, declaration: FuncExpr, closure: Environment, isInitFunc: bool = false): Function =
  var fun = Function()
  fun.name = name
  fun.isInitFunc = isInitFunc
  fun.declaration = declaration
  fun.closure = closure
  fun.arity = proc(): (int, int) =
    var atLeast: int = 0
    var atMost: int = 0
    for i in fun.declaration.parameters:
      if i of RequiredArg: atLeast += 1; atMost += 1
      if i of DefaultValued: atMost += 1
    return (atLeast, atMost)
  fun.call = proc(self: var Interpreter, args: seq[BaseType], token: Token): BaseType = 
    var environment = newEnv(closure)
    var parameters = fun.declaration.parameters
    for i in 0 ..< parameters.len:
      if parameters[i] of DefaultValued:
        if args.len-1 < i:
          environment.define(DefaultValued(parameters[i]).paramName.value, self.eval(DefaultValued(parameters[i]).default))
        else:
          environment.define(DefaultValued(parameters[i]).paramName.value, args[i])
      else:
        environment.define(RequiredArg(parameters[i]).paramName.value, args[i])
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

proc `bind`(self: Function, instance: ClassInstance): Function =
  var env = newEnv(self.closure)
  env.define("self", instance)
  return newFunction(self.name, self.declaration, env, self.isInitFunc)

proc newClassInstance(class: ClassType): ClassInstance = 
  var instance = ClassInstance(class: class, fields: initTable[string, BaseType]())
  return instance

proc newClass(metaclass: ClassType, superclass: ClassType, name: string, methods: Table[string, Function], token: Token): ClassType =
  var class = ClassType(name: name)
  class.arity = proc(): (int, int) = 
    let init = class.findMethod("new")
    if init.isNil: return (0, 0)
    else: return init.arity()
  class.call = proc(self: var Interpreter, args: seq[BaseType], token: Token): BaseType = 
    var instance = newClassInstance(class)
    var init = class.methods.getOrDefault("new", nil)
    if not init.isNil: discard `bind`(init, instance).call(self, args, token)
    return instance
  class.methods = methods
  class.cinstance = newClassInstance(metaclass)
  class.superclass = superclass
  return class

proc get(ci: ClassInstance, name: Token): BaseType =
  if ci.fields.hasKey(name.value): return ci.fields[name.value]
  let m = findMethod(ci.class, name.value)
  if not m.isNil: return m.`bind`(ci)
  error(name, RuntimeError, "Property '" & name.value & "' is not defined")

proc set(ci: ClassInstance, name: Token, value: BaseType) = ci.fields[name.value] = value

# ----------------------------------------------------------------------

# forward declarations for helper functions
proc isTruthy(self: var Interpreter, obj: BaseType): bool
proc doesEqual(self: var Interpreter, left: BaseType, right: BaseType): bool
proc lookUpVariable(self: var Interpreter, name: Token, expre: Expr): BaseType
proc interpret*(self: var Interpreter, statements: seq[Stmt])

proc plus(self: var Interpreter, left: BaseType, right: BaseType, expre: BinaryExpr): BaseType
proc minus(self: var Interpreter, left: BaseType, right: BaseType, expre: BinaryExpr): BaseType
proc slash(self: var Interpreter, left: BaseType, right: BaseType, expre: BinaryExpr): BaseType
proc star(self: var Interpreter, left: BaseType, right: BaseType, expre: BinaryExpr): BaseType 

proc resolve*(self: var Interpreter, expre: Expr, depth: int) =
  self.locals[expre] = depth

# this awkward import is for recursive import; DO NOT REMOVE THIS!!
import resolver

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
      error(expre.operator, RuntimeError, "All operands must be either string or int and float")
  of Bang:
    return newBool(self.isTruthy(right))
  else:
    discard

# eval VariableExpr
method eval(self: var Interpreter, expre: VariableExpr): BaseType =
  return self.lookUpVariable(expre.name, expre)

# eval ListOrMapVariableExpr
method eval(self: var Interpreter, expre: ListOrMapVariableExpr): BaseType =
  let indexOrKey = self.eval(expre.indexOrKey)
  let variable = self.eval(expre.variable)
  if variable of SlapList:
    if not (indexOrKey of SlapInt): error(expre.token, RuntimeError, "List indices must be integers")
    try:
      return SlapList(variable).values[SlapInt(indexOrKey).value]
    except IndexDefect:
      error(expre.token, RuntimeError, "Index out of range")
  
  elif variable of SlapMap:
    var map = SlapMap(variable).map
    var key = self.eval(expre.indexOrKey)
    for i in map.keys():
      if hash(i) == hash(key):
        return map[i]
    error(expre.token, RuntimeError, "Value with key '" & $key & "' does not exist")

  elif variable of SlapString:
    if not (indexOrKey of SlapInt): error(expre.token, RuntimeError, "String indices must be integers")
    let chars = toSeq(SlapString(variable).value.items)
    try:
      return newString($chars[SlapInt(indexOrKey).value])
    except IndexDefect:
      error(expre.token, RuntimeError, "Index out of range")
  else:
    error(expre.token, RuntimeError, "Only lists and maps can be used with '@[]'")

# eval AssignExpr
method eval(self: var Interpreter, expre: AssignExpr): BaseType =
  let value = self.eval(expre.value)
  if self.locals.contains(expre):
    let distance = self.locals[expre]
    self.env.assignAt(distance, expre.name, value)
  else:
    self.globals.assign(expre.name, value)
  return value

# eval ListOrMapAssignExpr
method eval(self: var Interpreter, expre: ListOrMapAssignExpr): BaseType = 
  var indexOrKey = self.eval(expre.indexOrKey)
  var value = self.eval(expre.value)
  if not (expre.variable of VariableExpr):
    var listOrMap = self.eval(expre.variable)
    if listOrMap of SlapList:
      if not (indexOrKey of SlapInt): error(expre.token, RuntimeError, "List indices must be integers")
      else: SlapList(listOrMap).values[SlapInt(indexOrKey).value] = value
    # elif listOrMap of SlapMap:
    #   var map = SlapMap(listOrMap)
  else:
    var name = VariableExpr(expre.variable).name
    if self.locals.hasKey(expre):
      var distance = self.locals[expre]
      self.env.listOrMapAssignAt(distance, name, value, indexOrKey)
    else:
      self.globals.listOrMapAssign(name, value, indexOrKey)
  
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
    error(expre.paren, RuntimeError, "Can only call classes and functions")
  let function = FuncType(callee)
  let (atLeast, atMost) = function.arity()
  if arguments.len < atLeast:
    error(expre.paren, RuntimeError, "Expected at least " & $atLeast & " argument(s) but got " & $arguments.len)
  if arguments.len > atMost:
    error(expre.paren, RuntimeError, "Expected at most " & $atMost & " argument(s) but got " & $arguments.len)
  return function.call(self, arguments, expre.paren)

# eval GetExpr
method eval(self: var Interpreter, expre: GetExpr): BaseType =
  let obj = self.eval(expre.instance)
  if obj of ClassInstance:
    return ClassInstance(obj).get(expre.name)
  elif obj of ClassType:
    return ClassType(obj).cinstance.get(expre.name)
  elif obj of ModuleClass:
    var module = ModuleClass(obj)
    for i in 0 ..< module.keys.len:
      if module.keys[i] == expre.name.value:
        return module.values[i]
    error(expre.name, RuntimeError, "'" & expre.name.value & "' is not defined in module " & module.name)

  error(expre.name, RuntimeError, "Only instances have properties")

# eval SetExpr
method eval(self: var Interpreter, expre: SetExpr): BaseType =
  let instance = self.eval(expre.instance)
  let value = self.eval(expre.value)
  if instance of ClassInstance:
    ClassInstance(instance).set(expre.name, value)
  elif instance of ModuleClass:
    var module = ModuleClass(instance)
    var setIt = false
    for i in 0 ..< module.keys.len():
      if module.keys[i] == expre.name.value:
        module.values[i] = value
        setIt = true
    if not setIt: error(expre.name, RuntimeError, "'" & $expre.name.value & "' is not defined in module " & module.name)
  else:
    error(expre.name, RuntimeError, "Only instances have fields")
  return value

# eval SelfExpr
method eval(self: var Interpreter, expre: SelfExpr): BaseType = return self.lookUpVariable(expre.keyword, expre)

# eval SuperExpr
method eval(self: var Interpreter, expre: SuperExpr): BaseType =
  let distance = self.locals[expre]
  let superclass = ClassType(self.env.getAt(distance, "super"))
  let obj = ClassInstance(self.env.getAt(distance-1, "self"))
  let m = superclass.findMethod(expre.classMethod.value)
  
  if m.isNil:
    error(expre.classMethod, RuntimeError, "'" & expre.classMethod.value & "' is not defined")
  return m.`bind`(obj)

# eval ListLiteralExpr
method eval(self: var Interpreter, expre: ListLiteralExpr): BaseType =
  var values: seq[BaseType]
  for value in expre.values:
    values.add(self.eval(value))
  return newList(values)

# eval MapLiteralExpr
method eval(self: var Interpreter, expre: MapLiteralExpr): BaseType =
  var map: Table[BaseType, BaseType]
  for i in 0 ..< expre.keys.len:
    map[self.eval(expre.keys[i])] = self.eval(expre.values[i])
  return newMap(map)

# eval BinaryExpr
method eval(self: var Interpreter, expre: BinaryExpr): BaseType =
  var left = self.eval(expre.left)
  var right = self.eval(expre.right)
  var fun: proc (self: var Interpreter, right: BaseType, left: BaseType, expre: BinaryExpr): BaseType

  case expre.operator.kind
    of Plus: # allows string concatenation and addition
      return self.plus(left, right, expre)
    of Minus:
      return self.minus(left, right, expre)
    of Slash: # division always returns a flost
      return self.slash(left, right, expre)
    of Star:
      return self.star(left, right, expre)
    of Modulo:
      if left of SlapInt and right of SlapInt:
        return newInt(SlapInt(left).value mod SlapInt(right).value)
      else:
        error(expre.operator, RuntimeError, "All operands must be int")
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
        error(expre.operator, RuntimeError, "All operands must be either int or float")
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
        error(expre.operator, RuntimeError, "All operands must be either int or float")
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
        error(expre.operator, RuntimeError, "All operands must be either int or float")
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
        error(expre.operator, RuntimeError, "All operands must be either int or float")
    of BangEqual: return newBool(not self.doesEqual(left, right))
    of EqualEqual: return newBool(self.doesEqual(left, right))

    of PlusEqual, PlusPlus: fun = plus
    of MinusEqual, MinusMinus: fun = minus
    of StarEqual: fun = star
    of SlashEqual: fun = slash
    else:
      discard
    
  if expre.left of VariableExpr:
    var name = VariableExpr(expre.left).name
    if self.locals.hasKey(expre.left):
      var distance = self.locals[expre.left]
      var valueBefore = self.env.getAt(distance, name.value)
      self.env.assignAt(distance, name, fun(self, valueBefore, right, expre))
    else:
      var valueBefore = self.globals.get(name)
      self.globals.assign(name, fun(self, valueBefore, right, expre))
  else:
    return fun(self, left, right, expre)

# --------------------------- STATEMENTS -------------------------------

method eval(self: var Interpreter, statement: Stmt) {.base, locks: "unknown".} = discard

method eval(self: var Interpreter, statement: ExprStmt) =
  discard self.eval(statement.expression)

method eval(self: var Interpreter, statement: VariableStmt) = 
  var value: BaseType = newNull() # defaults to null
  if not statement.init.isNil: value = self.eval(statement.init)
  self.env.define(statement.name.value, value)

method eval(self: var Interpreter, statement: FuncStmt) =
  let funcName = statement.name.value
  let function = newFunction(funcName, statement.function, self.env)
  self.env.define(funcName, function)

method eval(self: var Interpreter, expre: FuncExpr): BaseType =
  return newFunction("", expre, self.env)

proc executeBlock(self: var Interpreter, statements: seq[Stmt], environment: Environment) =
  let previous = self.env
  try:
    self.env = environment
    for i in statements:
      self.eval(i)
  finally:
    self.env = previous

method eval(self: var Interpreter, statement: BlockStmt) =
  self.executeBlock(statement.statements, newEnv(self.env))

method eval(self: var Interpreter, statement: ReturnStmt) =
  var value: BaseType
  if not statement.value.isNil: value = self.eval(statement.value)
  raise ReturnException(value: value)

method eval(self: var Interpreter, statement: WhileStmt) =
  try:
    while self.isTruthy(self.eval(statement.condition)):
      self.eval(statement.body)
  except OverflowDefect:
    error(statement.keyword, RuntimeError, "Over- or underflow")
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

method eval(self: var Interpreter, statement: ImportStmt) =
  var source: string = ""
  # this is for tracking source files
  token.sourceId += 1
  if not stdlibs.hasKey(statement.name.value):
    try:
      source = readFile(statement.name.value & ".slap")
    except IOError:
      error(statement.name, RuntimeError, "Cannot open '" & statement.name.value & ".slap'. No such file or directory")
  else:
    source = stdlibs[statement.name.value]
  var
    lexer = newLexer(source)
    tokens = lexer.tokenize()
    parser = newParser(tokens)
    nodes = parser.parse()
    interpreter = newInterpreter()
    resolver = newResolver(interpreter)
  resolver.resolve(nodes)
  interpreter = resolver.interpreter
  interpreter.interpret(nodes)
  
  for key, value in interpreter.globals.values:
    self.env.define(key, value)
  
  for key, value in interpreter.locals: self.locals[key] = value

method eval(self: var Interpreter, statement: ClassStmt) =
  var superclass: BaseType
  if not statement.superclass.isNil:
    superclass = self.eval(statement.superclass)
    if not (superclass of ClassType):
      error(statement.superclass.name, RuntimeError, "Superclass must be a class")
    
  self.env.define(statement.name.value, newNull())
  var classMethods = initTable[string, Function]()
  for m in statement.classMethods:
    let fun = newFunction(m.name.value, m.function, self.env, false)
    classMethods[m.name.value] = fun
  let metaclass = newClass(nil, nil, statement.name.value & " metaclass", classMethods, statement.name)

  if not statement.superclass.isNil:
    self.env = newEnv(self.env)
    self.env.define("super", superclass)

  var methods = initTable[string, Function]()
  for m in statement.methods:
    let function = newFunction(m.name.value, m.function, self.env, m.name.value == "new")
    methods[m.name.value] = function
  let class = newClass(metaclass, ClassType(superclass), statement.name.value, methods, statement.name)

  if not superclass.isNil: self.env = self.env.enclosing

  self.env.assign(statement.name, class)

# ----------------------------------------------------------------------

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
  elif left of SlapBool and right of SlapBool: return SlapBool(left).value == SlapBool(right).value
  else: return false

proc plus(self: var Interpreter, left: BaseType, right: BaseType, expre: BinaryExpr): BaseType =
  if left of SlapFloat and right of SlapFloat:
    return newFloat(SlapFloat(left).value + SlapFloat(right).value)
  elif left of SlapFloat and right of SlapInt:
    return newFloat(SlapFloat(left).value + float(SlapInt(right).value))
  elif left of SlapFloat and right of SlapString:
    return newString($SlapFloat(left).value & SlapString(right).value)
  elif left of SlapInt and right of SlapFloat:
    return newFloat(float(SlapInt(left).value) + SlapFloat(right).value)
  elif left of SlapInt and right of SlapInt:
    return newInt(SlapInt(left).value + SlapInt(right).value)
  elif left of SlapInt and right of SlapString:
    return newString($SlapInt(left).value & SlapString(right).value)
  elif left of SlapString and right of SlapString:
    return newString(SlapString(left).value & SlapString(right).value)
  elif left of SlapString and right of SlapInt:
    return newString(SlapString(left).value & $SlapInt(right).value)
  elif left of SlapString and right of SlapFloat:
    return newString(SlapString(left).value & $SlapFloat(right).value)
  else:
    error(expre.operator, RuntimeError, "All operands must be either string or int and float")

proc minus(self: var Interpreter, left: BaseType, right: BaseType, expre: BinaryExpr): BaseType =
  if left of SlapFloat and right of SlapFloat:
    return newFloat(SlapFloat(left).value - SlapFloat(right).value)
  elif left of SlapFloat and right of SlapInt:
    return newFloat(SlapFloat(left).value - float(SlapInt(right).value))
  elif left of SlapInt and right of SlapFloat:
    return newFloat(float(SlapInt(left).value) - SlapFloat(right).value)
  elif left of SlapInt and right of SlapInt:
    return newInt(SlapInt(left).value - SlapInt(right).value)
  else:
    error(expre.operator, RuntimeError, "All operands must be either string or int and float")

proc slash(self: var Interpreter, left: BaseType, right: BaseType, expre: BinaryExpr): BaseType =
  if left of SlapFloat and right of SlapFloat:
    if SlapFloat(right).value == 0:
      error(expre.operator, RuntimeError, "Cannot divide by 0")
    else:
      return newFloat(SlapFloat(left).value / SlapFloat(right).value)
  elif left of SlapFloat and right of SlapInt:
    if SlapInt(right).value == 0:
      error(expre.operator, RuntimeError, "Cannot divide by 0")
    else:
      return newFloat(SlapFloat(left).value / float(SlapInt(right).value))
  elif left of SlapInt and right of SlapFloat:
    if SlapFloat(right).value == 0:
      error(expre.operator, RuntimeError, "Cannot divide by 0")
    else:
      return newFloat(float(SlapInt(left).value) / SlapFloat(right).value)
  elif left of SlapInt and right of SlapInt:
    if SlapInt(right).value == 0:
      error(expre.operator, RuntimeError, "Cannot divide by 0")
    else:
      return newFloat(float(SlapInt(left).value) / float(SlapInt(right).value))
  else:
    error(expre.operator, RuntimeError, "All operands must be either int or float")

proc star(self: var Interpreter, left: BaseType, right: BaseType, expre: BinaryExpr): BaseType =
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
    error(expre.operator, RuntimeError, "All operands must be either int or float")

proc lookUpVariable(self: var Interpreter, name: Token, expre: Expr): BaseType = 
  if self.locals.hasKey(expre):
    let distance = self.locals[expre]
    return self.env.getAt(distance, name.value)
  else:
    return self.globals.get(name)
