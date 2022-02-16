# import strformat

# import token
# import tokenType

# var hadError* = false

# # Forward Declaration
# proc report(line: int, where: string, message: string)

# # Proc
# proc error*(line: int, message: string) =
#   report(line, "", message)

# proc error*(token: Token, message: string) =
#   if token.tkType == EOF:
#     report(token.line, " at end", message)
#   else:
#     report(token.line, " at '" & token.lexeme & "'", message)

# proc report(line: int, where: string, message: string) =
#   echo &"[line {$line}] Error{$where}: {$message}"
#   hadError = true

import std/strformat, strutils

type
  Error* = object
    source: string

proc error*(e: Error, line: int, errorName: string, message: string) =
  echo(fmt"line {line+1} -> {splitLines(e.source)[line]}")
  quit(fmt"{errorName}: {message}")