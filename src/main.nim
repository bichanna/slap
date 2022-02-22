#
# main.nim
# SLAP
#
# Created by Nobuharu Shimazu on 2/15/2022
# 

import os, lexer, error, parser, interpreter, node

# actually executes a source code
proc execute(source: string) = 
  # lexing
  let error = Error(source: source)
  var lexer = newLexer(source, error)
  let tokens = lexer.tokenize()
  
  # parsing
  var parser = newParser(tokens, error)
  let nodes = parser.parse()

  # interpreting
  var interpreter = newInterpreter(error)
  interpreter.interpret(nodes)

# reads a file and pass it to the execute func
proc runFile(path: string) =
  let source = readFile(path)
  execute(source)

# starts a new REPL session
proc repl() =
  node.isRepl = true
  try:
    while true:
      stdout.write(">> ")
      execute(readline(stdin))
  except EOFError:
    quit("\nBye!")

# handles Ctrl-C
proc handleCtrlC() {.noconv.} =
  quit("\nBye!")

when isMainModule:
  # just to handle Ctrl-C
  setControlCHook(handleCtrlC)

  let params = commandLineParams()
  if params.len > 1: quit("Usage: slap [filename.slap]")
  elif params.len == 1: runFile(params[0])
  else: repl()