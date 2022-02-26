#
# error.nim
# SLAP
#
# Created by Nobuharu Shimazu on 2/15/2022
# 

import std/strformat, strutils
import token, node

type
  Error* = object
    source*: string

proc error*(e: Error, line: int, errorName: string, message: string) =
  echo()
  if line >= -1:

    if line > 1:
      echo "\e[90m", fmt"{line-1}: {splitLines(e.source)[line-2]}", "\e[0m"

    if line > 0:
      echo "\e[90m", fmt"{line}: {splitLines(e.source)[line-1]}", "\e[0m"
    
    echo "\e[31m", fmt"{line+1}: {splitLines(e.source)[line]}"
    
    if line+1 < splitLines(e.source).len:
      echo "\e[90m", fmt"{line+2}: {splitLines(e.source)[line+1]}", "\e[0m"

    if line+2 < splitLines(e.source).len:
      echo "\e[90m", fmt"{line+3}: {splitLines(e.source)[line+2]}", "\e[0m"
    
  if node.isRepl:
    echo "\n", fmt"{errorName}: {message}", "\e[0m"
  else: quit("\n" & fmt"{errorName}: {message}" & "\e[0m")

proc error*(e: Error, token: Token, errorName: string, message: string) =
  e.error(token.line, errorName, message)