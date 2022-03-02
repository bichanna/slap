#
# builtin.nim
# SLAP
#
# Created by Nobuharu Shimazu on 2/28/2022
#

import slaptype, interpreterObj, error, env
import strutils

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

proc slapTypeof(self: var Interpreter, args: seq[BaseType]): BaseType =
  if args[0] of SlapNull: return newString("null")
  if args[0] of SlapInt: return newString("int")
  if args[0] of SlapList: return newString("list")
  if args[0] of SlapString: return newString("str")
  if args[0] of SlapBool: return newString("bool")
  if args[0] of Function or args[0] of FuncType: return newString("function")
  if args[0] of ClassType: return newString("class")
  if args[0] of ListInstance or args[0] of ClassInstance: return newString("instance")
  else: return newString("unknown")

proc slapInput(self: var Interpreter, args: seq[BaseType]): BaseType =
  if not (args[0] of SlapString): error(self.error, -1, RuntimeError, "input function only accepts a string")
  stdout.write(SlapString(args[0]).value)
  return newString(readLine(stdin))

proc slapGetStrAt(self: var Interpreter, args: seq[BaseType]): BaseType =
  if not (args[1] of SlapInt) or not (args[0] of SlapString):
    error(self.error, -1, RuntimeError, "at function only accepts an int and a string")
  return newString($SlapString(args[0]).value[SlapInt(args[1]).value])

proc slapIsInt(self: var Interpreter, args: seq[BaseType]): BaseType = return newBool(args[0] of SlapInt)

proc slapIsFloat(self: var Interpreter, args: seq[BaseType]): BaseType = return newBool(args[0] of SlapFloat)

proc slapIsBool(self: var Interpreter, args: seq[BaseType]): BaseType = return newBool(args[0] of SlapBool)

proc slapIsString(self: var Interpreter, args: seq[BaseType]): BaseType = return newBool(args[0] of SlapString)

proc slapIsList(self: var Interpreter, args: seq[BaseType]): BaseType = return newBool(args[0] of SlapList)

proc slapIsNull(self: var Interpreter, args: seq[BaseType]): BaseType = return newBool(args[0] of SlapNull)

proc slapConvertInt(self: var Interpreter, args: seq[BaseType]): BaseType =
  if args[0] of SlapInt: return SlapInt(args[0])
  if args[0] of SlapFloat: return newInt(SlapFloat(args[0]).value.toInt)
  if args[0] of SlapString:
    try: return newInt(parseInt(SlapString(args[0]).value))
    except: error(self.error, -1, RuntimeError, "Cannot convert to an integer")
  error(self.error, -1, RuntimeError, "Cannot convert to an integer")

proc slapConvertStr(self: var Interpreter, args: seq[BaseType]): BaseType =
  if args[0] of SlapInt: return newString($SlapInt(args[0]).value)
  if args[0] of SlapFloat: return newString($SlapFloat(args[0]).value)
  if args[0] of SlapNull: return newString($SlapNull(args[0]))
  if args[0] of SlapList: return newString($SlapList(args[0]).values)
  if args[0] of SlapString: return SlapString(args[0])
  if args[0] of SlapBool: return newString($SlapBool(args[0]).value)
  error(self.error, -1, RuntimeError, "Cannot convert to a string")

proc loadBuildins*(errorObj: Error): Environment =
  var globals = newEnv(errorObj)
  globals.define("println", FuncType(arity: proc(): int = 1, call: slapPrintln))
  globals.define("print", FuncType(arity: proc(): int = 1, call: slapPrint))
  globals.define("List", FuncType(arity: proc(): int = 1, call: slapList))
  globals.define("append", FuncType(arity: proc(): int = 2, call: slapAppend))
  globals.define("pop", FuncType(arity: proc(): int = 1, call: slapPop))
  globals.define("len", FuncType(arity: proc(): int = 1, call: slapLen))
  globals.define("type", FuncType(arity: proc(): int = 1, call: slapTypeof))
  globals.define("input", FuncType(arity: proc(): int = 1, call: slapInput))
  globals.define("at", FuncType(arity: proc(): int = 2, call: slapGetStrAt))
  globals.define("isInt", FuncType(arity: proc(): int = 1, call: slapIsInt))
  globals.define("isFloat", FuncType(arity: proc(): int = 1, call: slapIsFloat))
  globals.define("isBool", FuncType(arity: proc(): int = 1, call: slapIsBool))
  globals.define("isString", FuncType(arity: proc(): int = 1, call: slapIsString))
  globals.define("isList", FuncType(arity: proc(): int = 1, call: slapIsList))
  globals.define("isNull", FuncType(arity: proc(): int = 1, call: slapIsNull))
  globals.define("int", FuncType(arity: proc(): int = 1, call: slapConvertInt))
  globals.define("string", FuncType(arity: proc(): int = 1, call: slapConvertStr))

  return globals