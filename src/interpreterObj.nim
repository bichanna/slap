#
# interpreterObj.nim
# SLAP
#
# Created by Nobuharu Shimazu on 2/28/2022
#

import env, slaptype, node, token
import tables, strutils

type
  # Interpreter takes in an abstract syntax tree and executes
  Interpreter* = object
    env*: Environment
    globals*: Environment
    locals*: Table[Expr, int]
  
  FuncType* = ref object of BaseType
    call*: proc (self: var Interpreter, args: seq[BaseType], token: Token): BaseType
    arity*: proc (): int
  
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
  
  ModuleClass* = ref object of BaseType
    name*: string
    keys*: seq[string]
    values*: seq[BaseType]

proc newModuleClass*(name: string, keys: seq[string], values: seq[BaseType]): ModuleClass =
  return ModuleClass(name: name, keys: keys, values: values)

proc `$`*(obj: BaseType): string =
  if obj of SlapNull: return "null"
  elif obj of SlapInt: return $SlapInt(obj).value
  elif obj of SlapFloat: return $SlapFloat(obj).value
  elif obj of SlapString: return SlapString(obj).value
  elif obj of SlapBool: return $SlapBool(obj).value
  elif obj of SlapList: return $SlapList(obj).values
  elif obj of SlapMap:
    var str = "@{ "
    for key, value in SlapMap(obj).map:
      str &= $key & ":" & $value & " "
    return str & "}"
  elif obj of Function:
    if not Function(obj).name.isEmptyOrWhitespace : return "<fn " & Function(obj).name & ">"
    else: return "<anonymous fn>"
  elif obj of FuncType: return "<native fn>"
  elif obj of ClassType: return "<class " & ClassType(obj).name & ">"
  elif obj of ClassInstance: return "<instance " & ClassInstance(obj).class.name & ">"
  elif obj of ModuleClass: return "<module class>"
  
  # hopefully unreachable
  return "unknown type"