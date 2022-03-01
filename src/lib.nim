#
# lib.nim
# SLAP
#
# Created by Nobuharu Shimazu on 2/28/2022
#

import slaptype, interpreterObj, error, env

const RuntimeError = "RuntimeError"

proc slapPrintln(self: var Interpreter, args: seq[BaseType]): BaseType =
  stdout.write(args[0], "\n")
  return newNull()

proc slapPrint(self: var Interpreter, args: seq[BaseType]): BaseType =
  stdout.write(args[0])
  return newNull()

proc slapList(self: var Interpreter, args: seq[BaseType]): BaseType =
  return newListInstance(SlapList(args[0]))

proc slapAppend(self: var Interpreter, args: seq[BaseType]): BaseType = 
  if not (args[0] of SlapList):
    error(self.error, -1, RuntimeError, "append function only accepts a list and a value")
  SlapList(args[0]).values.add(args[1])
  return newNull()

proc slapPop(self: var Interpreter, args: seq[BaseType]): BaseType =
  if not (args[0] of SlapList):
    error(self.error, -1, RuntimeError, "pop function only accepts a list")
  return SlapList(args[0]).values.pop()

proc slapLen(self: var Interpreter, args: seq[BaseType]): BaseType =
  if args[0] of SlapString:
    return newInt(SlapString(args[0]).value.len)
  elif args[0] of SlapList:
    return newInt(SlapList(args[0]).values.len)
  error(self.error, -1, RuntimeError, "len function only accepts a list or string")


proc loadBuildins*(errorObj: Error): Environment =
  var globals = newEnv(errorObj)
  globals.define("println", FuncType(arity: proc(): int = 1, call: slapPrintln))
  globals.define("print", FuncType(arity: proc(): int = 1, call: slapPrint))
  globals.define("List", FuncType(arity: proc(): int = 1, call: slapList))
  globals.define("append", FuncType(arity: proc(): int = 2, call: slapAppend))
  globals.define("pop", FuncType(arity: proc(): int = 1, call: slapPop))
  globals.define("len", FuncType(arity: proc(): int = 1, call: slapLen))
  return globals