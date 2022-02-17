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

proc newInterpreter*(errorObj: Error): Interpreter =
  return Interpreter(
    error: errorObj
  )

# ----------------------------------------------------------------------

