#
# interpreterObj.nim
# SLAP
#
# Created by Nobuharu Shimazu on 2/28/2022
#

import ../env, slaptype, node, token, objhash
import tables, strutils, hashes

type
  # Interpreter takes in an abstract syntax tree and executes them!
  Interpreter* = ref object of RootObj
    env*: Environment
    globals*: Environment
    locals*: Table[Expr, int]
  
  # The base SLAP function type. SLAP anonymous functions are stuck with this.
  FuncType* = ref object of BaseType
    call*: proc (self: var Interpreter, args: seq[BaseType], token: Token): BaseType
    arity*: proc (): (int, int) # at-least arg length and at-most length
  
  # The base SLAP function type. All SLAP named functions are of this type.
  Function* = ref object of FuncType
    name*: string
    isInitFunc*: bool
    declaration*: FuncExpr
    closure*: Environment

  # The SLAP class type. This is the SLAP class itself, not its instances.
  ClassType* = ref object of FuncType
    name*: string
    methods*: Table[string, Function]
    cinstance*: ClassInstance
    superclass*: ClassType

  # This is the SLAP class instance type. Every instance of every class
  # is of this type.
  ClassInstance* = ref object of BaseType
    class*: ClassType
    fields*: Table[string, BaseType]

# Adds expressions (variables) to the locals table.
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
  
  # hopefully unreachable
  return "unknown type"