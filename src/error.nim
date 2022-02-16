import std/strformat, strutils

type
  Error* = object
    source: string

proc error*(e: Error, line: int, errorName: string, message: string) =
  echo(fmt"line {line+1} -> {splitLines(e.source)[line]}")
  quit(fmt"{errorName}: {message}")