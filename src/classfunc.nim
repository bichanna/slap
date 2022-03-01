import node, env, token, interpreterObj, slaptype, exception
import tables

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

proc set(ci: ClassInstance, name: Token, value: BaseType) = ci.fields[name.value] = value


proc executeBlock(self: var Interpreter, statements: seq[Stmt], environment: Environment) =
  let previous = self.env
  try:
    self.env = environment
    for i in statements:
      self.eval(i)
  finally:
    self.env = previous