#
# error.nim
# SLAP
#
# Created by Nobuharu Shimazu on 2/15/2022
# 

import std/strformat, strutils
import token

type
  Error* = object
    source*: string

proc error*(e: Error, line: int, errorName: string, message: string) =
  echo(fmt"line {line+1} -> {splitLines(e.source)[line]}")
  quit(fmt"{errorName}: {message}")

proc error*(e: Error, token: Token, errorName: string, message: string) =
  e.error(token.line, errorName, message)