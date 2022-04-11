#
# env.nim
# SLAP
#
# Created by Nobuharu Shimazu on 2/18/2022
#

import tables, hashes
import obj/[slaptype, token, objhash]
import error

const ErrorName = "RuntimeError"

type
  # Environment holds all the variables and values
  Environment* = ref object
    values*: Table[Hash, BaseType]
    enclosing*: Environment

# forward declarations
proc newEnv*(enclosing: Environment = nil): Environment
proc define*(env: var Environment, name: string, value: BaseType)
proc get*(env: var Environment, name: Token): BaseType
proc ancestor*(env: var Environment, distance: int): Environment
proc getAt*(env: var Environment, distance: int, name: string): BaseType
proc assign*(env: var Environment, name: Token, value: BaseType)
proc assignAt*(env: var Environment, distance: int, name: Token, value: BaseType)
proc listOrMapAssign*(env: var Environment, name: Token, value: BaseType, indexOrKey: BaseType)
proc listOrMapAssignAt*(env: var Environment, distance: int, name: Token, value: BaseType, indexOrKey: BaseType)

# This awkward import is for recursive import; DO NOT REMOVE THIS!!
# This is actually for debugging.
# import interpreterObj

# --------------------------------------------------------------

# This proc creates a new Environment and returns it.
proc newEnv*(enclosing: Environment = nil): Environment =
  return Environment(
    enclosing: enclosing,
    values: initTable[Hash, BaseType](),
  )

# This binds a variable name to a SLAP value.
proc define*(env: var Environment, name: string, value: BaseType) =
  var hashed: Hash
  hashed = name.hash
  env.values[hashed] = value

# This is for import statements.
proc define*(env: var Environment, name: Hash, value: BaseType) = env.values[name] = value

# This looks up the variable and returns its value.
# If none is found, throws a RuntimeError.
proc get*(env: var Environment, name: Token): BaseType =
  if env.values.hasKey(name.value.hash): return env.values[name.value.hash]
  if not env.enclosing.isNil: return env.enclosing.get(name)
  else:
    error(name, ErrorName, "'" & name.value & "' is not defined")

# This proc returns the local environments with the distance of `distance`
proc ancestor*(env: var Environment, distance: int): Environment =
  var environment = env
  for _ in 0 ..< distance: environment = environment.enclosing
  return environment

# This proc uses the ancestor proc above to get local varibles
proc getAt*(env: var Environment, distance: int, name: string): BaseType = return env.ancestor(distance).values[name.hash]

# This proc assigns a SLAP value to an already-existing varible.
proc assign*(env: var Environment, name: Token, value: BaseType) =
  if env.values.hasKey(name.value.hash):
    env.values[name.value.hash] = value
    return
  elif not env.enclosing.isNil:
    env.enclosing.assign(name, value)
    return
  error(name, ErrorName, "'" & name.value & "' is not defined")

# This proc uses the ancestor proc above to assign a SLAP value
# to an already-existing variable.
proc assignAt*(env: var Environment, distance: int, name: Token, value: BaseType) = env.ancestor(distance).values[name.value.hash] = value

# This is essentially the same as the assign proc but used with map and lists.
proc listOrMapAssign*(env: var Environment, name: Token, value: BaseType, indexOrKey: BaseType) =
  if env.values.hasKey(name.value.hash):
    let listOrMap = env.values[name.value.hash]
    if listOrMap of SlapList:
      if not (indexOrKey of SlapInt): error(name, ErrorName, "List indices must be integers")
      if SlapInt(indexOrKey).value < SlapList(listOrMap).values.len and SlapInt(indexOrKey).value > -1:
        SlapList(listOrMap).values[SlapInt(indexOrKey).value] = value
      else: 
        error(name, ErrorName, "Index out of range")
    
    elif listOrMap of SlapMap:
      SlapMap(listOrMap).map[indexOrKey] = value
  elif not env.enclosing.isNil:
    env.enclosing.listOrMapAssign(name, value, indexOrKey)
  else:
    error(name, ErrorName, "'" & name.value & "' is not defined")

# This is essentially the same as the assignAt proc but used with map and lists.
proc listOrMapAssignAt*(env: var Environment, distance: int, name: Token, value: BaseType, indexOrKey: BaseType) =
  let listOrMap = env.ancestor(distance).values[name.value.hash]
  if listOrMap of SlapList:
    if not (indexOrKey of SlapInt): error(name, ErrorName, "List indices must be integers")
    SlapList(listOrMap).values[SlapInt(indexOrKey).value] = value
  
  elif listOrMap of SlapMap:
    SlapMap(listOrMap).map[indexOrKey] = value
  
  else: error(name, ErrorName, "Only lists and maps can be used with '@[]'")