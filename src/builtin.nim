#
# builtin.nim
# SLAP
#
# Created by Nobuharu Shimazu on 2/28/2022
#

import env, error
import obj/[slaptype, interpreterObj, token]
import strutils, tables, sugar

const RuntimeError = "RuntimeError"

# This is just a forward declaration.
proc loadBuiltins*(): Environment  

# This is the SLAP `println` built-in function. This function just prints out
# whatever passed to it with a new line.
# signature: println(arg: str = "\n")
proc slapPrintln(self: var Interpreter, args: seq[BaseType], token: Token): BaseType =
  # If there's not argument, just prints a new line.
  if args.len == 0:
    stdout.write("\n")
  else:
    stdout.write(args[0], "\n")
  return newNull()

# This is the SLAP `print` built-in function. This function just prints out
# whatever passed to it WITHOUT a new line (use `println` instead if you want
# a new line at the end).
# signature: print(arg: str)
proc slapPrint(self: var Interpreter, args: seq[BaseType], token: Token): BaseType =
  stdout.write(args[0])
  return newNull()

# This is the SLAP `append` built-in function. This function accepts a list and 
# a SLAP value and appends the value at the end of the given list.
# signature: append(list: @[any], value: any)
proc slapAppend(self: var Interpreter, args: seq[BaseType], token: Token): BaseType = 
  if not (args[0] of SlapList):
    error(token, RuntimeError, "append function only accepts a list and a value")
  SlapList(args[0]).values.add(args[1])
  return newNull()

# This is the SLAP `pop` built-in function. This function accepts a list, 
# pops the last element of the list, and returns the popped value.
# signature: pop(list: @[any]): any
proc slapPop(self: var Interpreter, args: seq[BaseType], token: Token): BaseType =
  if not (args[0] of SlapList):
    error(token, RuntimeError, "pop function only accepts a list")
  return SlapList(args[0]).values.pop()

# This is the SLAP `len` built-in function. This function accepts a list
# or a string and returns the length of it as a SLAP int.
# signature: len(list: @[any]|str): int
proc slapLen(self: var Interpreter, args: seq[BaseType], token: Token): BaseType =
  if args[0] of SlapString:
    return newInt(SlapString(args[0]).value.len)
  elif args[0] of SlapList:
    return newInt(SlapList(args[0]).values.len)
  error(token, RuntimeError, "len function only accepts a list or string")

# This is the SLAP `type` built-in function. This function accepts anything
# and returns a SLAP string representation of it.
# signature: type(obj: any): str
proc slapTypeof(self: var Interpreter, args: seq[BaseType], token: Token): BaseType =
  if args[0] of SlapNull: return newString("null")
  if args[0] of SlapInt: return newString("int")
  if args[0] of SlapFloat: return newString("float")
  if args[0] of SlapList: return newString("list")
  if args[0] of SlapString: return newString("str")
  if args[0] of SlapBool: return newString("bool")
  if args[0] of Function or args[0] of FuncType: return newString("function")
  if args[0] of ClassType: return newString("class")
  else: return newString("unknown")

# This is the SLAP `input` built-in function. This function accepts a string
# and returns the input from the user.
# signature: input(text: str = null): str
proc slapInput(self: var Interpreter, args: seq[BaseType], token: Token): BaseType =
  if args.len == 1:
    if not (args[0] of SlapString): error(token, RuntimeError, "input function only accepts a string")
    stdout.write(SlapString(args[0]).value)
  return newString(readLine(stdin))

# This is the SLAP `isInt` built-in function. This function returns whether
# the passed argument is a SLAP int or not as a SLAP Boolean.
# signature: isInt(obj: any): bool
proc slapIsInt(self: var Interpreter, args: seq[BaseType], token: Token): BaseType = return newBool(args[0] of SlapInt)

# This is the SLAP `isFloat` built-in function. This function returns whether
# the passed argument is a SLAP float or not as a SLAP Boolean.
# signature: isFloat(obj: any): bool
proc slapIsFloat(self: var Interpreter, args: seq[BaseType], token: Token): BaseType = return newBool(args[0] of SlapFloat)

# This is the SLAP `isBool` built-in function. This function return whether
# the passed argument is a SLAP bool or not as a SLAP Boolean.
# signature: isBool(obj: any): bool
proc slapIsBool(self: var Interpreter, args: seq[BaseType], token: Token): BaseType = return newBool(args[0] of SlapBool)

# This is the SLAP `isStr` built-in function. This function return whether
# the passed argument is a SLAP string or not as a SLAP Boolean.
# signature: isStr(obj: any): bool
proc slapIsString(self: var Interpreter, args: seq[BaseType], token: Token): BaseType = return newBool(args[0] of SlapString)

# This is the SLAP `isList` built-in function. This function return whether
# the passed argument is a SLAP list or not as a SLAP Boolean.
# signature: isList(obj: any): bool
proc slapIsList(self: var Interpreter, args: seq[BaseType], token: Token): BaseType = return newBool(args[0] of SlapList)

# This is the SLAP `isMap` built-in function. This function return whether
# the passed argument is a SLAP map or not as a SLAP Boolean.
# signature: isMap(obj: any): bool
proc slapIsMap(self: var Interpreter, args: seq[BaseType], token: Token): BaseType = return newBool(args[0] of SlapMap)

# This is the SLAP `isBool` built-in function. This function return whether
# the passed argument is a SLAP null or not as a SLAP Boolean.
# signature: isNull(obj: any): bool
proc slapIsNull(self: var Interpreter, args: seq[BaseType], token: Token): BaseType = return newBool(args[0] of SlapNull)

# This is the SLAP `int` built-in function. This function tries to
# parse the given value to a SLAP int.
# signature: int(obj: any): int
proc slapConvertInt(self: var Interpreter, args: seq[BaseType], token: Token): BaseType =
  if args[0] of SlapInt: return SlapInt(args[0])
  if args[0] of SlapFloat: return newInt(SlapFloat(args[0]).value.toInt)
  if args[0] of SlapString:
    try: return newInt(parseInt(SlapString(args[0]).value))
    except: error(token, RuntimeError, "Cannot convert to an integer")
  error(token, RuntimeError, "Cannot convert to an integer")

# This is the SLAP `str` built-in function. This function tries to
# parse the given value to a SLAP string.
# signature: str(obj: any): str
proc slapConvertStr(self: var Interpreter, args: seq[BaseType], token: Token): BaseType =
  if args[0] of SlapInt: return newString($SlapInt(args[0]).value)
  if args[0] of SlapFloat: return newString($SlapFloat(args[0]).value)
  if args[0] of SlapNull: return newString($SlapNull(args[0]))
  if args[0] of SlapList: return newString($SlapList(args[0]).values)
  if args[0] of SlapString: return SlapString(args[0])
  if args[0] of SlapBool: return newString($SlapBool(args[0]).value)
  if args[0] of SlapMap: return newString($SlapMap(args[0]))
  error(token, RuntimeError, "Cannot convert to a string")

# This is the SLAP `keys` built-in function that returns the keys 
# of the given map.
# signature: keys(map: @{any: any}): @[any]
proc slapKeys(self: var Interpreter, args: seq[BaseType], token: Token): BaseType =
  if not (args[0] of SlapMap):
    error(token, RuntimeError, "keys function only accepts a map")
  var keys: seq[BaseType]
  for key, _ in SlapMap(args[0]).map: keys.add(key)
  return newList(keys)

# This is the SLAP `keys` built-in function that returns the values 
# of the given map.
# signature: values(map: @{any: any}): @[any]
proc slapValues(self: var Interpreter, args: seq[BaseType], token: Token): BaseType =
  if not (args[0] of SlapMap):
    error(token, RuntimeError, "values function only accepts a map")
  var values: seq[BaseType]
  for _, value in SlapMap(args[0]).map: values.add(value)
  return newList(values)

# This is the SLAP `upper` built-in function that returns
# a uppercased SLAP string.
# signature: upper(v: str): str
proc slapUpper(self: var Interpreter, args: seq[BaseType], token: Token): BaseType =
  if not (args[0] of SlapString):
    error(token, RuntimeError, "upper function only accepts a string")
  return newString(toUpper(SlapString(args[0]).value))

# This is the SLAP `lower` built-in function that returns
# a lowercased SLAP string.
# signature: lower(v: str): str
proc slapLower(self: var Interpreter, args: seq[BaseType], token: Token): BaseType =
  if not (args[0] of SlapString):
    error(token, RuntimeError, "lower function only accepts a string")
  return newString(toLower(SlapString(args[0]).value))

let JSPrompotFunc* = "// BE SURE TO INSTALL 'propmpt-sync'\nconst prompt238322184738283 = require(\"prompt-sync\")({sigint: true});\n\n"

let builtins* = [
  ("println", (0, 1), (args: seq[string]) -> string => "console.log(" & args.join(", ") & ")"),
  ("print", (1, 1), (args: seq[string]) -> string => "process.stdout.write(" & args.join(", ") & ")"),
  ("append", (2, 2), (args: seq[string]) -> string => args[0] & ".push(" & args[1] & ")"),
  ("pop", (1, 1), (args: seq[string]) -> string => args[0] & ".pop()"),
  ("len", (1, 1), (args: seq[string]) -> string => args[0] & ".length"),
  ("type", (1, 1), (args: seq[string]) -> string => "typeof " & args[0]),
  ("input", (0, 1), (args: seq[string]) -> string => "prompt238322184738283(" & (if args.len > 0: args[0] else: "\"\"") & ")"),
  ("isInt", (1, 1), (args: seq[string]) -> string => "Number.isInteger(" & args[0] & ")"),
  ("isFloat", (1, 1), (args: seq[string]) -> string => "(Number(" & args[0] & ") === " & args[0] & " && " & args[0] & " % 1 !== 0)"),
  ("isBool", (1, 1), (args: seq[string]) -> string => "(typeof " & args[0] & " === \"boolean\")"),
  ("isStr", (1, 1), (args: seq[string]) -> string => "(typeof " & args[0] & " === \"string\" )"),
  ("isList", (1, 1), (args: seq[string]) -> string => "Array.isArray(" & args[0] & ")"),
  ("isMap", (1, 1), (args: seq[string]) -> string => "(" & args[0] & ".constructor === Object)"),
  ("isNull", (1, 1), (args: seq[string]) -> string => "(" & args[0] & " === null)"),
  ("int", (1, 1), (args: seq[string]) -> string => "parseInt(" & args[0] & ")"),
  ("str", (1, 1), (args: seq[string]) -> string => "String(" & args[0] & ")"),
  ("keys", (1, 1), (args: seq[string]) -> string => "Object.keys(" & args[0] & ")"),
  ("values", (1, 1), (args: seq[string]) -> string => "Object.values(" & args[0] & ")"),
  ("upper", (1, 1), (args: seq[string]) -> string => args[0] & ".toUpperCase()"),
  ("lower", (1, 1), (args: seq[string]) -> string => args[0] & ".toLowerCase()"),
]

# This proc loads every built-in functions.
proc loadBuiltins*(): Environment =
  var globals = newEnv()
  
  # This is just a helper function for defining built-in functions.
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