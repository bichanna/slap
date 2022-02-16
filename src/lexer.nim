#
# lexer.nim
# SLAP
#
# Created by Nobuharu Shimazu on 2/16/2022
#

import tables, std/strformat, strutils
import token, error

const
  # keywords in SLAP
  keywords = {
    "defun": Defun,
    "class": Class,
    "and": And,
    "let": Let,
    "const": Const,
    "or": Or,
    "if": If,
    "elif": Elif, # this maybe deleted in the future
    "else": Else,
    "for": For,
    "super": Super,
    "while": While,
    "self": Self,
    "return": Return,
    "continue": Continue,
    "break": Break,
    "true": True,
    "false": False,
    "null": Null
  }.toTable

  Letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_"
  Digits = "0123456789"

type
  # Lexer takes in raw source code as a list of characters
  # and groups it into a list of tokens (seq[Token]).
  Lexer* = object
    source*: string
    error*: Error
    tokens*: seq[Token]
    current*, line*: int

proc newLexer*(source: string, errorObj: Error): Lexer = 
  return Lexer(
    source: source,
    error: errorObj,
    tokens: @[],
    current: 0,
    line: 0
  )

# ----------------------------------------------------------------------

# returns the current character and moves to the next one
proc advance(l: var Lexer): char {.discardable.} = 
  l.current += 1
  return l.source[l.current-1]

# returns the previous character and moves back to the previous one
proc reverse(l: var Lexer): char {.discardable.} =
  l.current -= 1
  return l.source[l.current]

# checks if EOF is reached
proc isAtEnd(l: var Lexer): bool = return l.current >= l.source.len

# appends a token to the list with a value or without a value
proc appendToken(l: var Lexer, ttype: TokenType, tvalue: string="") = 
  l.tokens.add(Token(
    kind: ttype,
    value: tvalue,
    line: l.line
  ))

# returns the current character
proc currentChar(l: var Lexer): char =
  if l.isAtEnd(): return '\0'
  else: return l.source[l.current]

# returns the current + 1 character without moving from the current position
proc nextChar(l: var Lexer): char =
  if l.current+1 >= l.source.len: return '\0'
  else: return l.source[l.current+1]

# checks if the current character matches the expected char
proc doesMatch(l: var Lexer, c: char): bool =
  result = true
  if l.isAtEnd(): result = false
  elif l.source[l.current] != c: result = false
  else: l.current += 1

# makes a SLAP string token and appends it to the list
proc makeString(l: var Lexer) = 
  var strValue: string = ""
  while l.currentChar() != '"' and not l.isAtEnd():
    if l.currentChar() == '\n': l.line += 1
    strValue.add(l.currentChar())
    l.advance()
  if l.currentChar() != '"': error(l.error, l.line, "SyntaxError", "Unterminated string, expected '\"'")
  l.advance()
  l.appendToken(String, strValue)

# makes a SLAP number (either an integer or a float) and appends it to the list
proc makeNumber(l: var Lexer) =
  var
    strNumber: string = ""
    hadDot: bool = false
  while l.currentChar() in Digits:
    strNumber.add(l.currentChar())
    l.advance()
  if l.currentChar() == '.' and l.nextChar() in Digits:
    hadDot = true
    strNumber.add(l.currentChar())
    l.advance()
    while l.currentChar() in Digits:
      strNumber.add(l.currentChar())
      l.advance()
  if hadDot: l.appendToken(Float, strNumber)
  else: l.appendToken(Int, strNumber)

