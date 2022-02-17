#
# interpreter.nim
# SLAP
#
# Created by Nobuharu Shimazu on 2/16/2022
#

import error

type
  # Interpreter takes in an abstract syntax tree and executes
  Interpreter* = object
    error*: Error

  SlapValueType* = enum
    slapString, slapInt, slapFloat, slapBool, slapNull

  SlapValue* = object
    case kind*: SlapValueType
    of slapString: strValue*: string
    of slapInt: intValue*: int64
    of slapBool: boolValue*: bool
    of slapFloat: floatValue*: float64
    of slapNull: nil

proc newInterpreter*(errorObj: Error): Interpreter =
  return Interpreter(
    error: errorObj
  )

# ----------------------------------------------------------------------

