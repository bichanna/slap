#
# main.nim
# SLAP
#
# Created by Nobuharu Shimazu on 2/15/2022
# 

import lexer, parser, interpreter, resolver, error
import os, parseopt

const HELP_MESSAGE = """
usage: slap [option] <filename>.slap
-h, --help             : show this message and exit
-v, --version          : show current SLAP version and exit
--showTokens:[on/off]  : show tokens generated from the source file
"""

const CURRENT_VERSION = "0.0.3"

# actually executes a source code
proc execute*(source: string) = 
  # lexing
  var lexer = newLexer(source)
  let tokens = lexer.tokenize()
  
  # parsing
  var parser = newParser(tokens)
  let nodes = parser.parse()

  # interpreting
  var
    interpreter = newInterpreter()
    resolver = newResolver(interpreter)
  resolver.resolve(nodes)
  interpreter = resolver.interpreter
  interpreter.interpret(nodes)

# reads a file and pass it to the execute func
proc runFile(path: string) =
  try:
    let source = readFile(path)
    execute(source)
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
  var isInTest = false
  while true:
    p.next()
    case p.kind:
    of cmdEnd: break
    of cmdShortOption, cmdLongOption:
      if p.key == "help" or p.key == "h":
        showHelp()
      elif p.key == "version" or p.key == "v":
        showVersion()
      elif p.key == "test":
        isInTest = true
    of cmdArgument:
      error.isTest = isInTest
      runFile(p.key)
      break