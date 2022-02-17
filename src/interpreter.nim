#
# interpreter.nim
# SLAP
#
# Created by Nobuharu Shimazu on 2/16/2022
#

import error, node, token
import strutils

type
  # Interpreter takes in an abstract syntax tree and executes
  Interpreter* = object
    error*: Error
  
  BaseType = ref object of RootObj

  SlapStr = ref object of BaseType
    value*: string

  SlapInt = ref object of BaseType
    value*: int64
  
  SlapFloat = ref object of BaseType
    value*: float64
  
  SlapBool = ref object of BaseType
    value*: bool
  
  SlapNull = ref object of BaseType

proc newInterpreter*(errorObj: Error): Interpreter =
  return Interpreter(
    error: errorObj
  )

proc newString(value: string): SlapStr = return SlapStr(value: value)

proc newInt(value: int64): SlapInt = return SlapInt(value: value)

proc newFloat(value: float64): SlapFloat = return SlapFloat(value: value)

proc newBool(value: bool): SlapBool = return SlapBool(value: value)

proc newNull(): SlapNull = return SlapNull()

# ----------------------------------------------------------------------

