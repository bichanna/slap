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
  Environment* = object
    values*: Table[string, BaseType]
    error*: Error

proc newEnv*(errorObj: Error): Environment =
  return Environment(
    values: initTable[string, BaseType](),
    error: errorObj
  )

# binds a name to a value
proc define*(env: var Environment, name: string, value: BaseType) = env.values[name] = value

# looks up the variable and returns its value
proc get*(env: var Environment, name: Token): BaseType =
  if env.values.hasKey(name.value): return env.values[name.value]
  else:
    error(env.error, name.line, "RuntimeError", "'" & name.value & "' is not defined")

# assign
proc assign*(env: var Environment, name: Token, value: BaseType) =
  if env.values.hasKey(name.value):
    env.values[name.value] = value
    return
  error(env.error, name.line, "RuntimeError", "'" & name.value & "' is not defined")