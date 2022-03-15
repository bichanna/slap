#
# interpreterObj.nim
# SLAP
#
# Created by Nobuharu Shimazu on 2/28/2022
#

import env, slaptype, node, token, objhash
import tables, strutils, hashes

type
  # Interpreter takes in an abstract syntax tree and executes
  Interpreter* = ref object of RootObj
    name*: string
    env*: Environment
    globals*: Environment
    locals*: Table[Expr, int]
  
  FuncType* = ref object of BaseType
    moduleHash*: Hash
    call*: proc (self: var Interpreter, args: seq[BaseType], token: Token): BaseType
    arity*: proc (): (int, int) # at-least arg length and at-most length
  
  Function* = ref object of FuncType
    name*: string
    isInitFunc*: bool
    declaration*: FuncExpr
    closure*: Environment

  ClassType* = ref object of FuncType
    name*: string
    methods*: Table[string, Function]
    cinstance*: ClassInstance
    superclass*: ClassType

  ClassInstance* = ref object of BaseType
    class*: ClassType
    fields*: Table[string, BaseType]

  ModuleObj* = ref object of BaseType
    interpreter*: Interpreter

var modules*: Table[Hash, ModuleObj]

proc newModuleObj*(self: var Interpreter, name: string, interp: Interpreter) =
  var moduleObj = ModuleObj(interpreter: interp)
  modules[moduleObj.interpreter.name.hash] = moduleObj
  self.env.define(name, moduleObj)

proc resolve*(self: var Interpreter, expre: Expr, depth: int) =
  self.locals[expre] = depth

proc `$`*(obj: BaseType): string =
  if obj of SlapNull: return "null"
  elif obj of SlapInt: return $SlapInt(obj).value
  elif obj of SlapFloat: return $SlapFloat(obj).value
  elif obj of SlapString: return SlapString(obj).value
  elif obj of SlapBool: return $SlapBool(obj).value
  elif obj of SlapList: return $SlapList(obj).values
  elif obj of SlapMap: return $SlapMap(obj).map
  elif obj of Function:
    if not Function(obj).name.isEmptyOrWhitespace : return "<fn " & Function(obj).name & ">"
    else: return "<anonymous fn>"
  elif obj of FuncType: return "<native fn>"
  elif obj of ClassType: return "<class " & ClassType(obj).name & ">"
  elif obj of ClassInstance: return "<instance " & ClassInstance(obj).class.name & ">"
  elif obj of ModuleObj: return "<module " & ModuleObj(obj).interpreter.name & ">"
  
  # hopefully unreachable
  return "unknown type"