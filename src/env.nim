#
# env.nim
# SLAP
#
# Created by Nobuharu Shimazu on 2/18/2022
#

import std/tables
import slaptype, token, error

type
  # Environment holds all the variables and values
  Environment* = ref object
    values*: Table[string, BaseType]
    error*: Error
    enclosing*: Environment

proc newEnv*(errorObj: Error, enclosing: Environment = nil): Environment =
  return Environment(
    enclosing: enclosing,
    values: initTable[string, BaseType](),
    error: errorObj
  )

# binds a name to a value
proc define*(env: var Environment, name: string, value: BaseType) = env.values[name] = value

# looks up the variable and returns its value
proc get*(env: var Environment, name: Token): BaseType =
  if env.values.hasKey(name.value): return env.values[name.value]
  if not env.enclosing.isNil: return env.enclosing.get(name)
  else:
    error(env.error, name.line, "RuntimeError", "'" & name.value & "' is not defined")

proc ancestor(env: var Environment, distance: int): Environment =
  var environment = env
  for _ in 0 ..< distance: environment = environment.enclosing
  return environment

proc getAt*(env: var Environment, distance: int, name: string): BaseType = return env.ancestor(distance).values[name]

# assign
proc assign*(env: var Environment, name: Token, value: BaseType) =
  if env.values.hasKey(name.value):
    env.values[name.value] = value
    return
  elif not env.enclosing.isNil:
    env.enclosing.assign(name, value)
    return
  error(env.error, name.line, "RuntimeError", "'" & name.value & "' is not defined")