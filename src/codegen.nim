#
# codegen.nim
# SLAP
#
# Created by Nobuharu Shimazu on 4/2/2022
#

import error, builtin, interpreter, lexer, parser, resolver
import obj/[node, token]
import sugar, sequtils, strutils, tables

const
  ErrorName = "CompilerError"

var
  hadInputFunc = false

# These are the base methods for the emit methods below.
method emit(expre: Expr, context: Table[string, string]): string {.base, locks: "unknown".} = discard
method emit(statement: Stmt, context: Table[string, string]): string {.base, locks: "unknown".} = discard

proc compile*(ast: seq[Stmt]): string

# ------------------------------------------------------------------------------------------
# forward declarations for helper procs

proc checkBuiltinFunc(funcName: string, args: seq[string], token: Token): string
proc initEmptyContext(): Table[string, string]

# ------------------------------------------------------------------------------------------

method emit(expre: LiteralExpr, context: Table[string, string]): string =
  case expre.kind:
  of String: return "\"" & expre.value & "\""
  of Int, Float: return expre.value
  of True: return "true"
  of False: return "false"
  of Null: return "null"
  else: discard

method emit(expre: GroupingExpr, context: Table[string, string]): string =
  "(" & emit(expre.expression, initEmptyContext()) & ")"

method emit(expre: UnaryExpr, context: Table[string, string]): string =
  expre.operator.value & emit(expre.right, initEmptyContext())

method emit(expre: BinaryExpr, context: Table[string, string]): string =
  if expre.operator.value != "++" and expre.operator.value != "--":
    emit(expre.left, initEmptyContext()) & " " & (if expre.operator.value == "==": "===" else: expre.operator.value) & " " & emit(expre.right, initEmptyContext())
  else:
    return emit(expre.left, initEmptyContext()) & expre.operator.value

method emit(expre: ListLiteralExpr, context: Table[string, string]): string =
  "[" & expre.values.map(x => emit(x, initEmptyContext())).join(", ") & "]"

method emit(expre: MapLiteralExpr, context: Table[string, string]): string =
  "{" & toSeq(0..<expre.keys.len).map(i => emit(expre.keys[i], initEmptyContext()) & ": " & emit(expre.values[i], initEmptyContext())).join(", ") & "}"

method emit(expre: LogicalExpr, context: Table[string, string]): string =
  result = emit(expre.left, initEmptyContext()) & " " & (if expre.operator.value == "and": "&&" else: "||") & " " & emit(expre.right, initEmptyContext())

method emit(expre: VariableExpr, context: Table[string, string]): string = expre.name.value

method emit(expre: ListOrMapVariableExpr, context: Table[string, string]): string =
  emit(expre.variable, initEmptyContext()) & "[" & emit(expre.indexOrKey, initEmptyContext()) & "]"

method emit(expre: AssignExpr, context: Table[string, string]): string =
  expre.name.value & " = " & emit(expre.value, initEmptyContext())

method emit(expre: ListOrMapAssignExpr, context: Table[string, string]): string =
  emit(expre.variable, initEmptyContext()) & "[" & emit(expre.indexOrKey, initEmptyContext()) & "]" & " = " & emit(expre.value, initEmptyContext())

method emit(expre: CallExpr, context: Table[string, string]): string =
  let args = expre.arguments.map(arg => emit(arg, initEmptyContext()))
  let callee = emit(expre.callee, initEmptyContext())
  let str = checkBuiltinFunc(callee, args, expre.paren)
  if str.isEmptyOrWhitespace:
    return callee & "(" & args.join(", ") & ")"
  else:
    return str

method emit(expre: GetExpr, context: Table[string, string]): string =
  emit(expre.instance, initEmptyContext()) & "." & expre.name.value

method emit(expre: SetExpr, context: Table[string, string]): string =
  emit(expre.instance, initEmptyContext()) & "." & expre.name.value & " = " & emit(expre.value, initEmptyContext())

method emit(expre: SuperExpr, context: Table[string, string]): string =
  "super." & expre.classMethod.value

method emit(expre: SelfExpr, context: Table[string, string]): string =
  "this"

method emit(expre: FuncExpr, context: Table[string, string]): string =
  proc getArgType(arg: FuncArg): string =
    if arg of DefaultValued: return DefaultValued(arg).paramName.value & "=" & emit(DefaultValued(arg).default, initEmptyContext())
    if arg of RequiredArg: return RequiredArg(arg).paramName.value
    if arg of RestArg: return "..." & RestArg(arg).paramName.value
  proc checkContext(): string =
    if context.hasKey("named"): return ""
    else: return "=> "
  return "(" & expre.parameters.map(param => getArgType(param)).join(", ") & ") " & checkContext() &
    "{\n\t" & expre.body.map(i => emit(i, initEmptyContext())).join("\n") & "\n}"

# -----------------------------------------------------------------------------------------------

method emit(statement: ExprStmt, context: Table[string, string]): string =
  emit(statement.expression, initEmptyContext()) & ";"

method emit(statement: VariableStmt, context: Table[string, string]): string =
  "var " & statement.name.value & " = " & emit(statement.init, initEmptyContext()) & ";"

method emit(statement: IfStmt, context: Table[string, string]): string =
  result = "if (" & emit(statement.condition, initEmptyContext()) & ") {\n\t" & emit(statement.thenBranch, initEmptyContext()) & "\n}"
  if statement.elifBranches.len != 0:
    for each in statement.elifBranches:
      result &= "else if (" & emit(each.condition, initEmptyContext()) & ") {\n\t" & emit(each.thenBranch, initEmptyContext()) & "\n}"
  if not statement.elseBranch.isNil:
    result &= "else {\n\t" & emit(statement.elseBranch, initEmptyContext()) & "\n}"

method emit(statement: BlockStmt, context: Table[string, string]): string =
  statement.statements.map(st => emit(st, initEmptyContext())).join(";\n")

method emit(statement: WhileStmt, context: Table[string, string]): string =
  "while (" & emit(statement.condition, initEmptyContext()) & ") {\n\t" & emit(statement.body, initEmptyContext()) & "}"

method emit(statement: FuncStmt, context: Table[string, string]): string =
  proc isMethod(): bool =
    context.hasKey("method")
  proc isStatic(): bool =
    context.hasKey("static")
  proc checkContext(): string =
    if isStatic(): return "static "
    else:
      if isMethod(): return "" else: return "function "
  
  result = checkContext() & (if statement.name.value == "new" and isMethod(): "constructor" else: statement.name.value) & emit(statement.function, {"named": "true"}.toTable)

method emit(statement: ReturnStmt, context: Table[string, string]): string =
  "return " & (if statement.value.isNil: "" else: emit(statement.value, initEmptyContext())) & ";"

method emit(statement: BreakStmt, context: Table[string, string]): string =
  "break;"

method emit(statement: ContinueStmt, context: Table[string, string]): string =
  "continue;"

method emit(statement: ImportStmt, context: Table[string, string]): string =
  var source: string
  var path: string
  var possiblePath = emit(statement.name, initEmptyContext()).replace("\"", "")
  
  if slapStdLibs.contains(possiblePath):
    source = slapStdLibs[possiblePath][0]
    path = slapStdLibs[possiblePath][1]
  
  elif stdLibs.contains(possiblePath):
    error(statement.keyword, ErrorName, "Cannot import written-in-Nim libraries.")
  
  else:
    path = possiblePath
    try:
      source = readFile(path)
    except IOError:
      error(statement.keyword, ErrorName, "Cannot open '" & path & "'.")
  
  # These are setups for really doing the job (importing).
  var
    lexer: Lexer
    tokens: seq[Token]
    parser: Parser
    nodes: seq[Stmt]
    resolver: Resolver
  
  # Here's where the lexing and parsing of the source
  # file occurs.
  try:
    lexer = newLexer(source, path)
    tokens = lexer.tokenize()
    parser = newParser(tokens)
    nodes = parser.parse()
    resolver = newResolver(newInterpreter())
  # If Nim catches OverflowDefect, it might mean that the user
  # is circular importing.
  except OverflowDefect:
    error(statement.keyword, ErrorName, "May be a circular import")
  
  resolver.resolve(nodes)

  return compile(nodes)

method emit(statement: ClassStmt, context: Table[string, string]): string =
  "class " & statement.name.value & (if statement.superclass.isNil: "" else: " extends " & emit(statement.superclass, initEmptyContext())) &
    " {\n\t" & statement.methods.map(mt => emit(mt, {"method": "true"}.toTable)).join(";\n") &
    statement.classMethods.map(cm => emit(cm, {"method": "true", "static": "true"}.toTable)).join(";\n") & "}"



proc compile*(ast: seq[Stmt]): string = 
  for s in ast:
    result &= emit(s, initEmptyContext()) & "\n\n"

  if hadInputFunc:
    result = JSPrompotFunc & result

# ----------------------------------------- HELPERS -----------------------------------------------

proc checkBuiltinFunc(funcName: string, args: seq[string], token: Token): string = 
  for bi in builtins:
    if bi[0] == funcName:
      if args.len <= bi[1][1] and args.len >= bi[1][0]:
        if bi[0] == "input":
          hadInputFunc = true
        return bi[2](args)
      else:
        error(token, ErrorName, "Expected at least " & $bi[1][0] & " or at most " & $bi[1][1] & " arguments but got " & $args.len)
  return ""

proc initEmptyContext(): Table[string, string] = return initTable[string, string]()