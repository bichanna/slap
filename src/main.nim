#
# main.nim
# SLAP
#
# Created by Nobuharu Shimazu on 2/15/2022
# 

import lexer, error, parser, interpreter, resolver
import os, parseopt

const HELP_MESSAGE = """
usage: slap [option] <filename>.slap
-h, --help             : show this message and exit
-v, --version          : show current SLAP version and exit
--showTokens:[on/off]  : show tokens generated from the source file
"""

const CURRENT_VERSION = "0.0.2"

# actually executes a source code
proc execute(source: string, showTokens: bool = false) = 
  # lexing
  let error = Error(source: source)
  var lexer = newLexer(source, error)
  let tokens = lexer.tokenize()
  if showTokens:
    echo("---------------TOKENS----------------\n" & $tokens & "\n---------------TOKENS----------------")
  
  # parsing
  var parser = newParser(tokens, error)
  let nodes = parser.parse()

  # interpreting
  var
    interpreter = newInterpreter(error)
    resolver = newResolver(interpreter, error)
  resolver.resolve(nodes)
  interpreter = resolver.interpreter
  interpreter.interpret(nodes)

# reads a file and pass it to the execute func
proc runFile(path: string, showTokens: bool) =
  try:
    let source = readFile(path)
    execute(source, showTokens)
  except IOError:
    quit("Cannot open '" & path & "'. No such file or directory")

# starts a new REPL session
# proc repl() =
#   node.isRepl = true
#   try:
#     while true:
#       stdout.write(">> ")
#       execute(readline(stdin))
#   except EOFError:
#     quit("\nBye!")

# show how to use SLAP CLI
proc showHelp() =
  stdout.write(HELP_MESSAGE & "\n")
  quit(0)

# show current SLAP version
proc showVersion() =
  stdout.write("SLAP " & CURRENT_VERSION & "\n")
  quit(0)

# handles Ctrl-C
proc handleCtrlC() {.noconv.} =
  quit("\nBye!")

when isMainModule:
  # just to handle Ctrl-C
  setControlCHook(handleCtrlC)

  # handle command line arguments and options
  var p = initOptParser(commandLineParams())
  var showTokens = false
  while true:
    p.next()
    case p.kind:
    of cmdEnd: break
    of cmdShortOption, cmdLongOption:
      if p.key == "help" or p.key == "h":
        showHelp()
      elif p.key == "version" or p.key == "v":
        showVersion()
      elif p.key == "showTokens":
        if p.val == "on": showTokens = true
        else: showTokens = false
    of cmdArgument:
      runFile(p.key, showTokens)
      break