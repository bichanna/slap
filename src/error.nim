#
# error.nim
# SLAP
#
# Created by Nobuharu Shimazu on 2/15/2022
# 

import strformat, strutils, tables
import obj/[token, node]

# `sources` stores paths.
var sources*: Table[int, string]

var isTest*: bool

# This is the place where errors are printed. Scary, right?
proc error*(sId: int8, line: int, errorName: string, message: string) =
  if isTest: # this is just for tests
    quit(fmt"{errorName}: {message}")
  else:
    let source = readFile(sources[sId])
    
    if line >= -1:

      if line > 1:
        echo "\e[90m", fmt"{line-1}: {splitLines(source)[line-2]}", "\e[0m"

      if line > 0:
        echo "\e[90m", fmt"{line}: {splitLines(source)[line-1]}", "\e[0m"
      
      echo "\e[31m", fmt"{line+1}: {splitLines(source)[line]}"
      
      if line+1 < splitLines(source).len:
        echo "\e[90m", fmt"{line+2}: {splitLines(source)[line+1]}", "\e[0m"

      if line+2 < splitLines(source).len:
        echo "\e[90m", fmt"{line+3}: {splitLines(source)[line+2]}", "\e[0m"
      
    if node.isRepl:
      echo "\n", fmt"{errorName}: {message}", "\e[0m"
    else: quit("\n" & fmt"{errorName}: {message}" & "\e[0m")

proc error*(token: Token, errorName: string, message: string) =
  error(token.sId, token.line, errorName, message)