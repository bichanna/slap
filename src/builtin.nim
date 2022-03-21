#
# builtin.nim
# SLAP
#
# Created by Nobuharu Shimazu on 2/28/2022
#

import slaptype, interpreterObj, error, env, token
import strutils, tables

const RuntimeError = "RuntimeError"

proc loadBuiltins*(): Environment  

proc slapPrintln(self: var Interpreter, args: seq[BaseType], token: Token): BaseType =
  if args.len == 0:
    stdout.write("\n")
  else:
    stdout.write(args[0], "\n")
  return newNull()

proc slapPrint(self: var Interpreter, args: seq[BaseType], token: Token): BaseType =
  stdout.write(args[0])
  return newNull()

proc slapAppend(self: var Interpreter, args: seq[BaseType], token: Token): BaseType = 
  if not (args[0] of SlapList):
    error(token, RuntimeError, "append function only accepts a list and a value")
  SlapList(args[0]).values.add(args[1])
  return newNull()

proc slapPop(self: var Interpreter, args: seq[BaseType], token: Token): BaseType =
  if not (args[0] of SlapList):
    error(token, RuntimeError, "pop function only accepts a list")
  return SlapList(args[0]).values.pop()

proc slapLen(self: var Interpreter, args: seq[BaseType], token: Token): BaseType =
  if args[0] of SlapString:
    return newInt(SlapString(args[0]).value.len)
  elif args[0] of SlapList:
    return newInt(SlapList(args[0]).values.len)
  error(token, RuntimeError, "len function only accepts a list or string")

proc slapTypeof(self: var Interpreter, args: seq[BaseType], token: Token): BaseType =
  if args[0] of SlapNull: return newString("null")
  if args[0] of SlapInt: return newString("int")
  if args[0] of SlapList: return newString("list")
  if args[0] of SlapString: return newString("str")
  if args[0] of SlapBool: return newString("bool")
  if args[0] of Function or args[0] of FuncType: return newString("function")
  if args[0] of ClassType: return newString("class")
  else: return newString("unknown")

proc slapInput(self: var Interpreter, args: seq[BaseType], token: Token): BaseType =
  if args.len == 1:
    if not (args[0] of SlapString): error(token, RuntimeError, "input function only accepts a string")
    stdout.write(SlapString(args[0]).value)
  return newString(readLine(stdin))

proc slapIsInt(self: var Interpreter, args: seq[BaseType], token: Token): BaseType = return newBool(args[0] of SlapInt)

proc slapIsFloat(self: var Interpreter, args: seq[BaseType], token: Token): BaseType = return newBool(args[0] of SlapFloat)

proc slapIsBool(self: var Interpreter, args: seq[BaseType], token: Token): BaseType = return newBool(args[0] of SlapBool)

proc slapIsString(self: var Interpreter, args: seq[BaseType], token: Token): BaseType = return newBool(args[0] of SlapString)

proc slapIsList(self: var Interpreter, args: seq[BaseType], token: Token): BaseType = return newBool(args[0] of SlapList)

proc slapIsMap(self: var Interpreter, args: seq[BaseType], token: Token): BaseType = return newBool(args[0] of SlapMap)

proc slapIsNull(self: var Interpreter, args: seq[BaseType], token: Token): BaseType = return newBool(args[0] of SlapNull)

proc slapConvertInt(self: var Interpreter, args: seq[BaseType], token: Token): BaseType =
  if args[0] of SlapInt: return SlapInt(args[0])
  if args[0] of SlapFloat: return newInt(SlapFloat(args[0]).value.toInt)
  if args[0] of SlapString:
    try: return newInt(parseInt(SlapString(args[0]).value))
    except: error(token, RuntimeError, "Cannot convert to an integer")
  error(token, RuntimeError, "Cannot convert to an integer")

proc slapConvertStr(self: var Interpreter, args: seq[BaseType], token: Token): BaseType =
  if args[0] of SlapInt: return newString($SlapInt(args[0]).value)
  if args[0] of SlapFloat: return newString($SlapFloat(args[0]).value)
  if args[0] of SlapNull: return newString($SlapNull(args[0]))
  if args[0] of SlapList: return newString($SlapList(args[0]).values)
  if args[0] of SlapString: return SlapString(args[0])
  if args[0] of SlapBool: return newString($SlapBool(args[0]).value)
  if args[0] of SlapMap: return newString($SlapMap(args[0]))
  error(token, RuntimeError, "Cannot convert to a string")

proc slapKeys(self: var Interpreter, args: seq[BaseType], token: Token): BaseType =
  if not (args[0] of SlapMap):
    error(token, RuntimeError, "keys function only accepts a map")
  var keys: seq[BaseType]
  for key, _ in SlapMap(args[0]).map: keys.add(key)
  return newList(keys)

proc slapValues(self: var Interpreter, args: seq[BaseType], token: Token): BaseType =
  if not (args[0] of SlapMap):
    error(token, RuntimeError, "values function only accepts a map")
  var values: seq[BaseType]
  for _, value in SlapMap(args[0]).map: values.add(value)
  return newList(values)

proc slapUpper(self: var Interpreter, args: seq[BaseType], token: Token): BaseType =
  if not (args[0] of SlapString):
    error(token, RuntimeError, "upper function only accepts a string")
  return newString(toUpper(SlapString(args[0]).value))

proc slapLower(self: var Interpreter, args: seq[BaseType], token: Token): BaseType =
  if not (args[0] of SlapString):
    error(token, RuntimeError, "lower function only accepts a string")
  return newString(toLower(SlapString(args[0]).value))

proc loadBuiltins*(): Environment =
  var globals = newEnv()
  
  proc def(name: string, arity: (int, int), call: proc(self: var Interpreter, args: seq[BaseType], token: Token): BaseType) =
    globals.define(
      name,
      FuncType(arity: proc(): (int, int) = arity,
      call: call)
    )
  
  def("println", (0, 1), slapPrintln)
  def("print", (1, 1), slapPrint)
  def("append", (2, 2), slapAppend)
  def("pop", (1, 1), slapPop)
  def("len", (1, 1), slapLen)
  def("type", (1, 1), slapTypeof)
  def("input", (0, 1), slapInput)
  def("isInt", (1, 1), slapIsInt)
  def("isFloat", (1, 1), slapIsFloat)
  def("isBool", (1, 1), slapIsBool)
  def("isStr", (1, 1), slapIsString)
  def("isList", (1, 1), slapIsList)
  def("isMap", (1, 1), slapIsMap)
  def("isNull", (1, 1), slapIsNull)
  def("int", (1, 1), slapConvertInt)
  def("str", (1, 1), slapConvertStr)
  def("keys", (1, 1), slapKeys)
  def("values", (1, 1), slapValues)
  def("upper", (1, 1), slapUpper)
  def("lower", (1, 1), slapLower)

  return globals