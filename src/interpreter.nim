#
# interpreter.nim
# SLAP
#
# Created by Nobuharu Shimazu on 2/16/2022
#

import error, node

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

# ----------------------------------------------------------------------

