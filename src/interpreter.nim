#
# interpreter.nim
# SLAP
#
# Created by Nobuharu Shimazu on 2/16/2022
#

import error, env, builtin, lexer, resolver, parser
import ../lib/[io, os]
import obj/[node, token, slaptype, exception, interpreterObj, objhash]
import strutils, tables, sequtils, hashes
  
const
  RuntimeError = "RuntimeError"

  # the paths of libraries written in SLAP
  stdpath = "lib/stdlib.slap"
  strpath = "lib/strlib.slap"
  mathpath = "lib/mathlib.slap"

  # the sources of libraries written in SLAP
  libstd = staticRead "../" & stdpath
  libstr = staticRead "../" & strpath
  libmath = staticRead "../" & mathpath

# libraries written in SLAP
const slapStdLibs* = {
    "std": @[libstd, stdpath],
    "strutils": @[libstr, strpath],
    "math": @[libmath, mathpath],
  }.toTable

# libraries written in Nim
const stdLibs* = {
    "os": loadOSLib,
    "io": loadIOLib,
  }.toTable

# executeBlock executes a block, `{...}`, which could be the body of a
# function, method, loop, or just a stand-alone block.
proc executeBlock(self: var Interpreter, statements: seq[Stmt], environment: Environment)

# This is the base method for every eval procs that evaluate
# every expression and statement.
method eval(self: var Interpreter, expre: Expr): BaseType {.base, locks: "unknown".}

# the "constructor" for the Interpreter object
proc newInterpreter*(): Interpreter =
  # This loads all the built-in functions that can be used
  # without any importing.
  var globals = loadBuiltins()
  return Interpreter(env: globals, globals: globals, locals: initTable[Expr, int]())

# ----------------------------- FUNCTIONS & CLASSES ----------------------------------

# newFunction creates a new SLAP function, Function, and returns it.
proc newFunction(name: string, declaration: FuncExpr, closure: Environment, isInitFunc: bool = false): Function =
  var fun = Function()
  fun.name = name
  fun.isInitFunc = isInitFunc
  fun.declaration = declaration
  fun.closure = closure
  fun.arity = proc(): (int, int) =
    # This handles required arguments, default arguments, and rest arguments.
    var atLeast: int = 0
    var atMost: int = 0
    for i in fun.declaration.parameters:
      if i of RequiredArg: atLeast += 1; atMost += 1
      elif i of DefaultValued: atMost += 1
      elif i of RestArg:
        atLeast += 1
        # The max length of arguments (when using a rest arguemnt) is defined by
        # the highest value of Nim int type. So, when user have to pass a big
        # content, passing it as a list rather than rest arguments is encouraged.
        # e.g., `function(1, 2, 3, ..., 100000);` is discouraged.
        # Use a list instead: `function([1, 2, 3, ..., 100000]);`
        atMost = high(int)
        # no more arguments can follow a rest argument
        break
    return (atLeast, atMost)
  fun.call = proc(self: var Interpreter, args: seq[BaseType], token: Token): BaseType = 
    # This function is called when a SLAP function, Function, is called.
    # e.g., `someFunc();`
    var environment = newEnv(closure)
    var parameters = fun.declaration.parameters
    for i in 0 ..< parameters.len:
      # Before, executing the body, allocate arguments.
      if parameters[i] of DefaultValued:
        if args.len-1 < i:
          environment.define(DefaultValued(parameters[i]).paramName.value, self.eval(DefaultValued(parameters[i]).default))
        else:
          environment.define(DefaultValued(parameters[i]).paramName.value, args[i])
      elif parameters[i] of RestArg:
        var list: seq[BaseType]
        for j in i ..< args.len: list.add(args[j])
        environment.define(RestArg(parameters[i]).paramName.value, newList(list))
      else:
        environment.define(RequiredArg(parameters[i]).paramName.value, args[i])
    
    try:
      # actually running the body of the function
      self.executeBlock(declaration.body, environment)
    except ReturnException as rx:
      # This occurs when a return statement is hit.
      return rx.value
    
    # If this function being created is the constructor of a class object, 
    # returns the object itself automatically.
    if isInitFunc: return fun.closure.getAt(0, "self")
    
    # If there's nothing returned from this fucntion, just returns SLAP null.
    return newNull()

  return fun

# Given a class, findMethod finds a method of an object and returns it.
proc findMethod(ct: ClassType, name: string): Function =
  if ct.methods.hasKey(name): return ct.methods[name]
  if not ct.superclass.isNil: return ct.superclass.findMethod(name)
  return nil

# bind binds the class object itself to the special `self` variable.
proc `bind`(self: Function, instance: ClassInstance): Function =
  var env = newEnv(self.closure)
  env.define("self", instance)
  return newFunction(self.name, self.declaration, env, self.isInitFunc)

# newClassInstance creates a new SLAP class instance (object), ClassInstance, of
# the given class and returns it.
proc newClassInstance(class: ClassType): ClassInstance = 
  var instance = ClassInstance(class: class, fields: initTable[string, BaseType]())
  return instance

# newClass creates a SLAP class, ClassType, and returns it.
proc newClass(metaclass: ClassType, superclass: ClassType, name: string, methods: Table[string, Function], token: Token): ClassType =
  var class = ClassType(name: name)
  class.arity = proc(): (int, int) = 
    # automatically creating a constructor for the class
    # in case that here's no user-written constructor.
    let init = class.findMethod("new")
    if init.isNil: return (0, 0)
    else: return init.arity()
  class.call = proc(self: var Interpreter, args: seq[BaseType], token: Token): BaseType = 
    # This creates a new SLAP class instance (object), ClassInstance,
    # finds the constructor, and returns it. If there's no user-written
    # constructor, it uses the default constructor.
    var instance = newClassInstance(class)
    var init = class.methods.getOrDefault("new", nil)
    if not init.isNil: discard `bind`(init, instance).call(self, args, token)
    return instance
  # This sets methods to the newly created class instance (object).
  class.methods = methods
  class.cinstance = newClassInstance(metaclass)
  class.superclass = superclass
  return class

# get gets a instance method and returns it.
proc get(ci: ClassInstance, name: Token, i: var Interpreter): BaseType =
  if ci.fields.hasKey(name.value): return ci.fields[name.value]
  let m = findMethod(ci.class, name.value)
  if not m.isNil: return `bind`(m, ci)
  error(name, RuntimeError, "Property '" & name.value & "' is not defined")

# set binds a new class property to the given class instance.
proc set(ci: ClassInstance, name: Token, value: BaseType) = ci.fields[name.value] = value

# ----------------------------------------------------------------------

# forward declarations for the helper procs
proc addGlobals(self: var Interpreter, locals: Table[Expr, int], env: Environment, statement: ImportStmt)
proc isTruthy(self: var Interpreter, obj: BaseType): bool
proc doesEqual(self: var Interpreter, left: BaseType, right: BaseType): bool
proc lookUpVariable(self: var Interpreter, name: Token, expre: Expr): BaseType
proc interpret*(self: var Interpreter, statements: seq[Stmt])

# forward declarations for binary expression procs
proc plus(self: var Interpreter, left: BaseType, right: BaseType, expre: BinaryExpr): BaseType
proc minus(self: var Interpreter, left: BaseType, right: BaseType, expre: BinaryExpr): BaseType
proc slash(self: var Interpreter, left: BaseType, right: BaseType, expre: BinaryExpr): BaseType
proc star(self: var Interpreter, left: BaseType, right: BaseType, expre: BinaryExpr): BaseType 

# --------------------------- EXPRESSIONS ------------------------------

# This eval is the base method for every expression eval procs.
# If this eval is called, it means that I don't handle every expressions.
method eval(self: var Interpreter, expre: Expr): BaseType {.base, locks: "unknown".} = discard

# This eval evaluates a LiteralExpr, which is just a SLAP string, Int,
# Boolean, or Null, and returns it as a BaseType.
method eval(self: var Interpreter, expre: LiteralExpr): BaseType =
  case expre.kind
  of String: return newString(expre.value)
  of Int: return newInt(parseInt(expre.value))
  of Float: return newFloat(parseFloat(expre.value))
  of True: return newBool(true)
  of False: return newBool(false)
  of Null: return newNull()
  else: discard

# This eval handles a GroupingExpr. This proc passes the inner expression
# to another, appropriate eval method.
method eval(self: var Interpreter, expre: GroupingExpr): BaseType =
  return self.eval(expre.expression)

# This eval evaluates a UnaryExpr, which is something like `-4` and `!false`.
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
    return newBool(not self.isTruthy(right))
  else:
    discard

# This eval method just calls the lookUpVariable helper proc to
# find the given variable and returns it as a BaseType.
method eval(self: var Interpreter, expre: VariableExpr): BaseType =
  return self.lookUpVariable(expre.name, expre)

# This eval handles a ListOrMapVariableExpr, which is something like
# `list@[0];` and `map@["key"];`.
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

# This eval evaluates an AssignExpr.
# e.g., `someVar = "assigning some string";`
method eval(self: var Interpreter, expre: AssignExpr): BaseType =
  let value = self.eval(expre.value)
  if self.locals.contains(expre):
    let distance = self.locals[expre]
    self.env.assignAt(distance, expre.name, value)
  else:
    self.globals.assign(expre.name, value)
  return value

# This eval handles assignments to lists and maps. And 
# eventually returns the new value as a BaseType.
# e.g., `list@[2] = "a new value";` and `map@["key"] = "some value";`
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
    var variable = VariableExpr(expre.variable)
    if self.locals.hasKey(variable):
      var distance = self.locals[variable]
      self.env.listOrMapAssignAt(distance, name, value, indexOrKey)
    else:
      self.globals.listOrMapAssign(name, value, indexOrKey)
  
  return value

# This eval handles SLAP logical expressions, `and` and `or`.
method eval(self: var Interpreter, expre: LogicalExpr): BaseType =
  let left = self.eval(expre.left)
  if expre.operator.kind == Or:
    if self.isTruthy(left): return left
  else:
    if not self.isTruthy(left): return left
  return self.eval(expre.right)

# This eval handles function calls. It checks the number of
# the given arguments and the expected arity.
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

# This eval evaluates instance (object) properties or methods, and 
# returns it if it finds one.
method eval(self: var Interpreter, expre: GetExpr): BaseType =
  let obj = self.eval(expre.instance)
  if obj of ClassInstance:
    return ClassInstance(obj).get(expre.name, self)
  elif obj of ClassType:
    return ClassType(obj).cinstance.get(expre.name, self)

  error(expre.name, RuntimeError, "Only instances have properties")

# This eval handles assignments of instance fields.
method eval(self: var Interpreter, expre: SetExpr): BaseType =
  let instance = self.eval(expre.instance)
  let value = self.eval(expre.value)
  if instance of ClassInstance:
    ClassInstance(instance).set(expre.name, value)
  else:
    error(expre.name, RuntimeError, "Only instances have fields")
  return value

# This eval is basically the same as the eval of VariableExprs, but
# this always tries to find `self`.
method eval(self: var Interpreter, expre: SelfExpr): BaseType = return self.lookUpVariable(expre.keyword, expre)

# This eval handles `super` keyword if the given class inherits
# a super class.
method eval(self: var Interpreter, expre: SuperExpr): BaseType =
  let distance = self.locals[expre]
  let superclass = ClassType(self.env.getAt(distance, "super"))
  let obj = ClassInstance(self.env.getAt(distance-1, "self"))
  let m = superclass.findMethod(expre.classMethod.value)
  
  # If this if statement is triggered, it means that this class
  # inherits no super class, or the super class does not have
  # this method.
  if m.isNil:
    error(expre.classMethod, RuntimeError, "'" & expre.classMethod.value & "' is not defined")
  return `bind`(m, obj)

# This eval method handles/creates list literals and returns it.
# e.g., `[1, 2, 3];`
method eval(self: var Interpreter, expre: ListLiteralExpr): BaseType =
  var values: seq[BaseType]
  for value in expre.values:
    values.add(self.eval(value))
  return newList(values)

# This eval handles/creates map literals and returns it.
# e.g., `{"key", "value", "key2": "value2"};`
method eval(self: var Interpreter, expre: MapLiteralExpr): BaseType =
  var map: Table[BaseType, BaseType]
  for i in 0 ..< expre.keys.len:
    map[self.eval(expre.keys[i])] = self.eval(expre.values[i])
  return newMap(map)

# THis method handles binary expressions, `+`, `-`, `*`, etc.
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

# the base method for the statement eval methods
method eval(self: var Interpreter, statement: Stmt) {.base, locks: "unknown".} = discard

# This eval evaluates a ExprStmt, which is just an expression in 
# a statement wrapper, so this calls an appropriate expression eval proc.
method eval(self: var Interpreter, statement: ExprStmt) =
  discard self.eval(statement.expression)

# This eval handles variable declarations.
# e.g., `let someVar = 123;`
method eval(self: var Interpreter, statement: VariableStmt) = 
  var value: BaseType = newNull() # defaults to null
  if not statement.init.isNil: value = self.eval(statement.init)
  self.env.define(statement.name.value, value)

# This eval creates named functions.
method eval(self: var Interpreter, statement: FuncStmt) =
  let funcName = statement.name.value
  let function = newFunction(funcName, statement.function, self.env)
  self.env.define(funcName, function)

# This eval creates unnamed (anonymous) functions.
method eval(self: var Interpreter, expre: FuncExpr): BaseType =
  return newFunction("", expre, self.env)

# executeBlock executes a block, `{...}`, which could be the body of a
# function, method, loop, or just a stand-alone block.
proc executeBlock(self: var Interpreter, statements: seq[Stmt], environment: Environment) =
  let previous = self.env
  try:
    self.env = environment
    for i in statements:
      self.eval(i)
  finally:
    self.env = previous

# This just calls the executeBlock proc.
method eval(self: var Interpreter, statement: BlockStmt) =
  self.executeBlock(statement.statements, newEnv(self.env))

# This eval method handles return statements. This throws ReturnException.
method eval(self: var Interpreter, statement: ReturnStmt) =
  var value: BaseType
  if not statement.value.isNil: value = self.eval(statement.value)
  raise ReturnException(value: value)

# This is the loop eval. This handles while and for loops.
method eval(self: var Interpreter, statement: WhileStmt) =
  try:
    while self.isTruthy(self.eval(statement.condition)):
      try:
        self.eval(statement.body)
      except ContinueException:
        discard
  except OverflowDefect:
    error(statement.keyword, RuntimeError, "Over- or underflow")
  # just returns (breaks) out of a loop
  except BreakException: return

# This eval method handles if statements.
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

# just throws BreakException and hopes that a loop catches it
method eval(self: var Interpreter, statement: BreakStmt) = raise BreakException()

# just throws ContinueException and hopes that a loop catches it
method eval(self: var Interpreter, statement: ContinueStmt) = raise ContinueException()

# This eval method creates SLAP classes.
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

  # If this class inherits a super class, then add the super class's methods
  # and properties to this class.
  if not superclass.isNil: self.env = self.env.enclosing

  self.env.assign(statement.name, class)

# This handles import statements.
method eval(self: var Interpreter, statement: ImportStmt) =
  var source: string
  var path: string

  # This checks if the path is a SLAP string. I could've removed this
  # because  all tokens have a string representation, and I could've
  # just used that to get paths. But this is just a preference.
  var possiblePath = self.eval(statement.name)
  if not (possiblePath of SlapString): error(statement.keyword, RuntimeError, "Path must be string")

  let strPossiblePath = SlapString(possiblePath).value
  
  # If one of the SLAP-written std libraries matches the path,
  # just set it as the source.
  if slapStdLibs.contains(strPossiblePath):
    source = slapStdLibs[strPossiblePath][0]
    path = slapStdLibs[strPossiblePath][1]
  # If one of the Nim-written libraries matches the path,
  # just stops here and add its globals to the current
  # global environment.
  elif stdLibs.contains(strPossiblePath):
    var globals = stdLibs[strPossiblePath]()
    var locals: Table[Expr, int]
    self.addGlobals(locals, globals, statement)
    return
  # If the path doesn't match any std libraries, then
  # try to open it as a file, and add the content as the
  # source.
  else:
    path = strPossiblePath
    try:
      source = readFile(path)
    except IOError:
      error(statement.keyword, RuntimeError, "Cannot open '" & path & "'.")
  
  # These are setups for really doing the job (importing).
  var
    lexer: Lexer
    tokens: seq[Token]
    parser: Parser
    nodes: seq[Stmt]
    resolver: Resolver
  
  # Here's where the lexing and parsing of the source
  # file occurs.
  try:
    lexer = newLexer(source, path)
    tokens = lexer.tokenize()
    parser = newParser(tokens)
    nodes = parser.parse()
    resolver = newResolver(newInterpreter())
  # If Nim catches OverflowDefect, it might mean that the user
  # is circular importing.
  except OverflowDefect:
    error(statement.keyword, RuntimeError, "Might be a circular import")
  
  # Just before interpreting the nodes, resolve scopes.
  resolver.resolve(nodes)
  var interpreter = resolver.interpreter
  # And here, creates a new interpreter object and 
  # interpret the nodes.
  interpreter.interpret(nodes)

  # After all of these, add them to the global environment.
  self.addGlobals(interpreter.locals, interpreter.env, statement)

# ----------------------------------------------------------------------

# This proc gets called from the outside world,
# and starts interpreting nodes.
proc interpret*(self: var Interpreter, statements: seq[Stmt]) =
  for s in statements:
    self.eval(s)

# ---------------------------- HELPERS ---------------------------------

# This proc appends a global environment to another one.
proc addGlobals(self: var Interpreter, locals: Table[Expr, int], env: Environment, statement: ImportStmt) =
  # I'm lazy, so I just add the locals to the current locals.
  for key, value in locals: self.locals[key] = value
  
  # This checks whether the user wants to import everything or
  # just a portion of them.
  if statement.imports.len == 0 or statement.imports[0] == "*".hash:
    for key, value in env.values:
      self.env.define(key, value)
  # If the user just wants to import some of the imported globals,
  # this gets triggered.
  else:
    for key, value in env.values:
      if statement.imports.contains(key):
        self.env.define(key, value)

# If obj, a BaseType, is not a SLAP Null, and SLAP false, 
# then returns true.
proc isTruthy(self: var Interpreter, obj: BaseType): bool =
  if obj of SlapNull: return false
  if obj of SlapBool: return SlapBool(obj).value
  else: return true

# This proc checks if two SLAP values equal.
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

# This is the helper function that does the addtion.
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
  elif left of SlapInt and right of SlapString:
    return newString($SlapInt(left).value & SlapString(right).value)
  elif left of SlapFloat and right of SlapString:
    return newString($SlapFloat(left).value & SlapString(right).value)
  else:
    error(expre.operator, RuntimeError, "All operands must be either string or int and float")

# This is the helper function that does the subtraction.
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

# This is the helper function that does the division.
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

# This is the helper function that does the multiplication.
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
    # This allow something like this:
    # `"hello " * 3` => `hello hello hello `
    var str = ""
    for i in 0 ..< SlapInt(right).value: str &= SlapString(left).value
    return newString(str)
  else:
    error(expre.operator, RuntimeError, "All operands must be either int or float")

# This helper proc does the real work of finding a varible
# and returns it if found.
proc lookUpVariable(self: var Interpreter, name: Token, expre: Expr): BaseType = 
  if self.locals.hasKey(expre):
    let distance = self.locals[expre]
    return self.env.getAt(distance, name.value)
  else:
    return self.globals.get(name)
