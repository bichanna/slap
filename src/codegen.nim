#
# codegen.nim
# SLAP
#
# Created by Nobuharu Shimazu on 4/2/2022
#

import node, token, error
import sugar, sequtils, strutils, builtin

const
  ErrorName = "CompilerError"

var isNamedFunc = false

# These are the base methods for the emit methods below.
method emit(expre: Expr): string {.base, locks: "unknown".} = discard
method emit(statement: Stmt): string {.base, locks: "unknown".} = discard

# ------------------------------------------------------------------------------------------
# forward declarations for helper procs

proc checkBuiltinFunc(funcName: string, args: seq[string], token: Token): string

# ------------------------------------------------------------------------------------------

method emit(expre: LiteralExpr): string =
  case expre.kind:
  of String: return "\"" & expre.value & "\""
  of Int, Float: return expre.value
  of True: return "true"
  of False: return "false"
  of Null: return "null"
  else: discard

method emit(expre: GroupingExpr): string =
  "(" & emit(expre.expression) & ")"

method emit(expre: UnaryExpr): string =
  expre.operator.value & emit(expre.right)

method emit(expre: BinaryExpr): string =
  if expre.operator.value != "++" and expre.operator.value != "--":
    emit(expre.left) & " " & (if expre.operator.value == "==": "===" else: expre.operator.value) & " " & emit(expre.right)
  else:
    return emit(expre.left) & expre.operator.value

method emit(expre: ListLiteralExpr): string =
  "[" & expre.values.map(x => emit(x)).join(", ") & "]"

method emit(expre: MapLiteralExpr): string =
  "{" & toSeq(0..<expre.keys.len).map(i => emit(expre.keys[i]) & ": " & emit(expre.values[i])).join(", ") & "}"

method emit(expre: LogicalExpr): string =
  result = emit(expre.left) & " " & (if expre.operator.value == "and": "&&" else: "||") & " " & emit(expre.right)

method emit(expre: VariableExpr): string = expre.name.value

method emit(expre: ListOrMapVariableExpr): string =
  emit(expre.variable) & "[" & emit(expre.indexOrKey) & "]"

method emit(expre: AssignExpr): string =
  expre.name.value & " = " & emit(expre.value)

method emit(expre: ListOrMapAssignExpr): string =
  emit(expre.variable) & "[" & emit(expre.indexOrKey) & "]" & " = " & emit(expre.value)

method emit(expre: CallExpr): string =
  let args = expre.arguments.map(arg => emit(arg))
  let fun = emit(expre.callee)
  let str = checkBuiltinFunc(fun, args, expre.paren)
  if str.isEmptyOrWhitespace:
    return fun & "(" & args.join(",") & ")"
  else:
    return str

method emit(expre: GetExpr): string =
  emit(expre.instance) & "." & expre.name.value

method emit(expre: SetExpr): string =
  emit(expre.instance) & "." & expre.name.value & " = " & emit(expre.value)

method emit(expre: SuperExpr): string =
  "super." & expre.classMethod.value

method emit(expre: SelfExpr): string =
  "this"

method emit(expre: FuncExpr): string =
  proc getArgType(arg: FuncArg): string =
    if arg of DefaultValued: return DefaultValued(arg).paramName.value & "=" & emit(DefaultValued(arg).default)
    if arg of RequiredArg: return RequiredArg(arg).paramName.value
    if arg of RestArg: return "..." & RestArg(arg).paramName.value
  return "(" & expre.parameters.map(param => getArgType(param)).join(", ") & ") " & (if isNamedFunc: "" else: "=> ") &
    "{\n\t" & expre.body.map(i => emit(i)).join("\n") & "\n}"

# -----------------------------------------------------------------------------------------------

method emit(statement: ExprStmt): string =
  emit(statement.expression) & ";"

method emit(statement: VariableStmt): string =
  "var " & statement.name.value & " = " & emit(statement.init)

method emit(statement: IfStmt): string =
  result = "if (" & emit(statement.condition) & ") {\n\t" & emit(statement.thenBranch) & "\n}"
  if statement.elifBranches.len != 0:
    for each in statement.elifBranches:
      result &= "else if (" & emit(each.condition) & ") {\n\t" & emit(each.thenBranch) & "\n}"
  if not statement.elseBranch.isNil:
    result &= "else {\n\t" & emit(statement.elseBranch) & "\n}"

method emit(statement: BlockStmt): string =
  statement.statements.map(st => emit(st)).join(";\n")

method emit(statement: WhileStmt): string =
  "while (" & emit(statement.condition) & ") {\n\t" & emit(statement.body) & "}"

method emit(statement: FuncStmt): string =
  isNamedFunc = true
  result = "function " & statement.name.value & emit(statement.function)
  isNamedFunc = false

method emit(statement: ReturnStmt): string =
  "return " & (if statement.value.isNil: "" else: emit(statement.value)) & ";"

method emit(statement: BreakStmt): string =
  "break;"

method emit(statement: ContinueStmt): string =
  "continue;"

# TODO: Implement emit method for ImportStmt node
method emit(statement: ImportStmt): string =
  discard

method emit(statement: ClassStmt): string =
  "class " & statement.name.value & (if statement.superclass.isNil: "" else: " extends " & emit(statement.superclass)) &
    " {\n\t" & statement.methods.map(mt => emit(mt)).join(";\n") &
    statement.classMethods.map(cm => emit(cm)).join(";\n") & "}"



proc compile*(ast: seq[Stmt]): string = 
  result = "\n/*\n\tCompiled by the SLAP compiler!\n*/\n\n"
  for s in ast:
    result &= emit(s) & ";\n\n"

# ----------------------------------------- HELPERS -----------------------------------------------

proc checkBuiltinFunc(funcName: string, args: seq[string], token: Token): string = 
  for bi in builtins:
    if bi[0] == funcName:
      if args.len <= bi[1][1] and args.len >= bi[1][0]:
        return bi[2](args)
      else:
        error(token, ErrorName, "Expected at least " & $bi[1][0] & " or at most " & $bi[1][1] & " arguments but got " & $args.len)
  return ""