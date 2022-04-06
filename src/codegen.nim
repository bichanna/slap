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

type
  # This enum specifies the target language which SLAP is compiled to.
  # Currently, SLAP supports only JavaScript as a target language.
  TargetLang* = enum
    JAVASCRIPT,
    
  # CodeGenerator takes in an abstract syntax tree and tanspile to
  # the target language (currenlty, only JS is available).
  CodeGenerator* = object
    ast: seq[Stmt]
    language: TargetLang

proc newCodeGenerator*(nodes: seq[Stmt], language: TargetLang): CodeGenerator =
  return CodeGenerator(ast: nodes, language: language)

# These are the base methods for the emit methods below.
method emit(self: CodeGenerator, expre: Expr): string {.base, locks: "unknown".} = discard
method emit(self: CodeGenerator, statement: Stmt): string {.base, locks: "unknown".} = discard

# ------------------------------------------------------------------------------------------
# forward declarations for helper procs

proc checkBuiltinFunc(self: CodeGenerator, funcName: string, args: seq[string], token: Token): string

# ------------------------------------------------------------------------------------------

method emit(self: CodeGenerator, expre: LiteralExpr): string =
  case expre.kind:
  of String: return "\"" & expre.value & "\""
  of Int, Float: return expre.value
  of True: return "true"
  of False: return "false"
  of Null: return "null"
  else: discard

method emit(self: CodeGenerator, expre: GroupingExpr): string =
  "(" & self.emit(expre.expression) & ")"

method emit(self: CodeGenerator, expre: UnaryExpr): string =
  expre.operator.value & self.emit(expre.right)

method emit(self: CodeGenerator, expre: BinaryExpr): string =
  if expre.operator.value != "++" and expre.operator.value != "--":
    self.emit(expre.left) & " " & (if expre.operator.value == "==": "===" else: expre.operator.value) & " " & self.emit(expre.right)
  else:
    return self.emit(expre.left) & expre.operator.value

method emit(self: CodeGenerator, expre: ListLiteralExpr): string =
  "[" & expre.values.map(x => self.emit(x)).join(", ") & "]"

method emit(self: CodeGenerator, expre: MapLiteralExpr): string =
  "{" & toSeq(0..<expre.keys.len).map(i => self.emit(expre.keys[i]) & ": " & self.emit(expre.values[i])).join(", ") & "}"

method emit(self: CodeGenerator, expre: LogicalExpr): string =
  result = self.emit(expre.left) & " " & (if expre.operator.value == "and": "&&" else: "||") & " " & self.emit(expre.right)

method emit(self: CodeGenerator, expre: VariableExpr): string = expre.name.value

method emit(self: CodeGenerator, expre: ListOrMapVariableExpr): string =
  self.emit(expre.variable) & "[" & self.emit(expre.indexOrKey) & "]"

method emit(self: CodeGenerator, expre: AssignExpr): string =
  expre.name.value & " = " & self.emit(expre.value)

method emit(self: CodeGenerator, expre: ListOrMapAssignExpr): string =
  self.emit(expre.variable) & "[" & self.emit(expre.indexOrKey) & "]" & " = " & self.emit(expre.value)

method emit(self: CodeGenerator, expre: CallExpr): string =
  let args = expre.arguments.map(arg => self.emit(arg))
  let fun = self.emit(expre.callee)
  let str = self.checkBuiltinFunc(fun, args, expre.paren)
  if str.isEmptyOrWhitespace:
    return fun & "(" & args.join(",") & ")"
  else:
    return str

method emit(self: CodeGenerator, expre: GetExpr): string =
  self.emit(expre.instance) & "." & expre.name.value

method emit(self: CodeGenerator, expre: SetExpr): string =
  self.emit(expre.instance) & "." & expre.name.value & " = " & self.emit(expre.value)

method emit(self: CodeGenerator, expre: SuperExpr): string =
  "super." & expre.classMethod.value

method emit(self: CodeGenerator, expre: SelfExpr): string =
  "this"

method emit(self: CodeGenerator, expre: FuncExpr): string =
  proc getArgType(arg: FuncArg): string =
    if arg of DefaultValued: return DefaultValued(arg).paramName.value & "=" & self.emit(DefaultValued(arg).default)
    if arg of RequiredArg: return RequiredArg(arg).paramName.value
    if arg of RestArg: return "..." & RestArg(arg).paramName.value
  return "(" & expre.parameters.map(param => getArgType(param)).join(", ") & ") " & (if isNamedFunc: "" else: "=> ") &
    "{\n\t" & expre.body.map(i => self.emit(i)).join("\n") & "\n}"

# -----------------------------------------------------------------------------------------------

method emit(self: CodeGenerator, statement: ExprStmt): string =
  self.emit(statement.expression) & ";"

method emit(self: CodeGenerator, statement: VariableStmt): string =
  "var " & statement.name.value & " = " & self.emit(statement.init)

method emit(self: CodeGenerator, statement: IfStmt): string =
  result = "if (" & self.emit(statement.condition) & ") {\n\t" & self.emit(statement.thenBranch) & "\n}"
  if statement.elifBranches.len != 0:
    for each in statement.elifBranches:
      result &= "else if (" & self.emit(each.condition) & ") {\n\t" & self.emit(each.thenBranch) & "\n}"
  if not statement.elseBranch.isNil:
    result &= "else {\n\t" & self.emit(statement.elseBranch) & "\n}"

method emit(self: CodeGenerator, statement: BlockStmt): string =
  statement.statements.map(st => self.emit(st)).join(";\n")

method emit(self: CodeGenerator, statement: WhileStmt): string =
  "while (" & self.emit(statement.condition) & ") {\n\t" & self.emit(statement.body) & "}"

method emit(self: CodeGenerator, statement: FuncStmt): string =
  isNamedFunc = true
  result = "function " & statement.name.value & self.emit(statement.function)
  isNamedFunc = false

method emit(self: CodeGenerator, statement: ReturnStmt): string =
  "return " & (if statement.value.isNil: "" else: self.emit(statement.value)) & ";"

method emit(self: CodeGenerator, statement: BreakStmt): string =
  "break;"

method emit(self: CodeGenerator, statement: ContinueStmt): string =
  "continue;"

# TODO: Implement emit method for ImportStmt node
method emit(self: CodeGenerator, statement: ImportStmt): string =
  discard

method emit(self: CodeGenerator, statement: ClassStmt): string =
  "class " & statement.name.value & (if statement.superclass.isNil: "" else: " extends " & self.emit(statement.superclass)) &
    " {\n\t" & statement.methods.map(mt => self.emit(mt)).join(";\n") &
    statement.classMethods.map(cm => self.emit(cm)).join(";\n") & "}"



proc compile*(self: CodeGenerator): string = 
  result = "\n/*\n\tCompiled by the SLAP compiler!\n*/\n\n"
  for s in self.ast:
    result &= self.emit(s) & ";\n\n"

# ----------------------------------------- HELPERS -----------------------------------------------

proc checkBuiltinFunc(self: CodeGenerator, funcName: string, args: seq[string], token: Token): string = 
  for bi in builtins:
    if bi[0] == funcName:
      if args.len <= bi[1][1] and args.len >= bi[1][0]:
        return bi[2](args)
      else:
        error(token, ErrorName, "Expected at least " & $bi[1][0] & " or at most " & $bi[1][1] & " arguments but got " & $args.len)
  return ""