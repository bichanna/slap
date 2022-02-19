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
  echo "\e[31m", fmt"{line+1}: {splitLines(e.source)[line]}"
  if node.isRepl: echo(fmt"{errorName}: {message}" & "\e[0m")
  else: quit(fmt"{errorName}: {message}" & "\e[0m")

proc error*(e: Error, token: Token, errorName: string, message: string) =
  e.error(token.line, errorName, message)