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

# binds a name to a value
proc define*(env: var Environment, name: string, value: BaseType) = env.values[name] = value

# looks up the variable and returns its value
proc get*(env: var Environment, name: Token): BaseType =
  if env.values.hasKey(name.value): return env.values[name.value]
  else:
    error(env.error, name.line, "RuntimeError", "'" & name.value & "' is not defined")