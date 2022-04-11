#
# os.nim
# SLAP
#
# Created by Nobuharu Shimazu on 3/20/2022
#

import ../src/obj/[slaptype, interpreterObj, token]
import ../src/[error, env]
import osproc

const RuntimeError = "RuntimeError"

proc loadOSLib*(): Environment

proc slapExecuteProcess*(self: var Interpreter, args: seq[BaseType], token: Token): BaseType =
  if not (args[0] of SlapString):
    error(token, RuntimeError, "execProcess only accepts a string")
  return newInt(execCmd(SlapString(args[0]).value))

proc loadOSLib*(): Environment = 
  var globals = newEnv()
  
  proc def(name: string, arity: (int, int), call: proc(self: var Interpreter, args: seq[BaseType], token: Token): BaseType) =
    globals.define(
      name,
      FuncType(arity: proc(): (int, int) = arity,
      call: call)
    )
  
  def("execProcess", (1, 1), slapExecuteProcess)

  return globals