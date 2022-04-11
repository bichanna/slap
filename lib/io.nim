#
# os.nim
# SLAP
#
# Created by Nobuharu Shimazu on 3/20/2022
#

import ../src/obj/[slaptype, interpreterObj, token]
import ../src/[error, env]

const RuntimeError = "RuntimeError"

proc loadIOLib*(): Environment

proc slapReadFile(self: var Interpreter, args: seq[BaseType], token: Token): BaseType =
  if not (args[0] of SlapString):
    error(token, RuntimeError, "readFile only accepts a string")
  
  try:
    return newString(readFile(SlapString(args[0]).value))
  except IOError:
    error(token, RuntimeError, "Cannot open " & SlapString(args[0]).value)

proc slapWriteln(self: var Interpreter, args: seq[BaseType], token: Token): BaseType =
  if not (args[0] of SlapString):
    error(token, RuntimeError, "Path to the file must be string")

  try:
    let file = open(SlapString(args[0]).value, fmWrite)
    defer: file.close()
    file.writeLine(SlapString(args[1]).value)
  except IOError:
    error(token, RuntimeError, "Cannot open or write to " & SlapString(args[0]).value)
  
  return newNull()

proc slapWrite(self: var Interpreter, args: seq[BaseType], token: Token): BaseType =
  if not (args[0] of SlapString):
    error(token, RuntimeError, "Path to the file must be string")

  try:
    let file = open(SlapString(args[0]).value, fmWrite)
    defer: file.close()
    file.write(SlapString(args[1]).value)
  except IOError:
    error(token, RuntimeError, "Cannot open or write to " & SlapString(args[0]).value)
  
  return newNull()

proc loadIOLib*(): Environment =
  var globals = newEnv()

  proc def(name: string, arity: (int, int), call: proc(self: var Interpreter, args: seq[BaseType], token: Token): BaseType) =
    globals.define(
      name,
      FuncType(arity: proc(): (int, int) = arity,
      call: call)
    )

  def("readFile", (1, 1), slapReadFile)
  def("writeln", (2, 2), slapWriteln)
  def("write", (2, 2), slapWrite)
  
  return globals
