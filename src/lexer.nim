#
# lexer.nim
# SLAP
#
# Created by Nobuharu Shimazu on 2/16/2022
#

import tables, std/strformat
import token, error

const
  # keywords in SLAP
  keywords = {
    "define": Define,
    "class": Class,
    "static": Static,
    "and": And,
    "let": Let,
    "const": Const,
    "or": Or,
    "if": If,
    "elif": Elif,
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
    "null": Null,
    "import": Import
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

# skips the rest of a block comment
proc skipBlockComment(l: var Lexer) =
  var nesting = 1
  while nesting > 0:
    if l.currentChar() == '\n': l.line += 1
    if l.currentChar() == '\0': error(l.error, l.line, "SyntaxError", "Unterminated block comment")
    if l.currentChar() == '#' and l.nextChar() == '{':
      l.advance()
      l.advance()
      nesting += 1
      continue

    if l.currentChar() == '}' and l.nextChar() == '#':
      l.advance()
      l.advance()
      nesting -= 1
      continue

    l.advance()

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

# makes an identifier and appends it to the list
proc makeIdentifier(l: var Lexer) =
  var identifier: string = ""
  while l.currentChar() in Letters:
    identifier.add(l.currentChar())
    l.advance()
  if keywords.hasKey(identifier):
    if identifier == "self": l.appendToken(keywords[identifier], "self")
    elif identifier == "super": l.appendToken(keywords[identifier], "super")
    else: l.appendToken(keywords[identifier])
  else: l.appendToken(Identifier, identifier)

proc tokenize*(l: var Lexer): seq[Token] =
  var c: char
  while not l.isAtEnd():
    c = l.advance()
    case c:
    of '(': l.appendToken(LeftParen)
    of ')': l.appendToken(RightParen)
    of '[': l.appendToken(LeftBracket)
    of ']': l.appendToken(RightBracket)
    of '{': l.appendToken(LeftBrace)
    of '}': l.appendToken(RightBrace)
    of ':': l.appendToken(Colon)
    of ';': l.appendToken(SemiColon)
    of '+': l.appendToken(Plus)
    of '-':
      if l.doesMatch('>'): l.appendToken(RightArrow)
      else: l.appendToken(Minus)
    of '~': l.appendToken(Tilde)
    of '*': l.appendToken(Star)
    of '%': l.appendToken(Modulo)
    of '/': l.appendToken(Slash)
    of '@': l.appendToken(At)
    of '^': l.appendToken(Caret)
    of ',': l.appendToken(Comma)
    of '$': l.appendToken(Let)
    of '"': l.makeString()
    of '&': # `&property` is a shortcut for `self.property`
      l.appendToken(Self, "self")
      l.appendToken(Dot)
    of '!':
      if l.doesMatch('='): l.appendToken(BangEqual)
      else: l.appendToken(Bang)
    of '<':
      if l.doesMatch('-'): l.appendToken(LeftArrow)
      elif l.doesMatch('='): l.appendToken(LessEqual)
      else: l.appendToken(Less)
    of '=':
      if l.doesMatch('='): l.appendToken(EqualEqual)
      else: l.appendToken(Equals)
    of '>':
      if l.doesMatch('='): l.appendToken(GreaterEqual)
      else: l.appendToken(Greater)
    of '.':
      if l.doesMatch('.'): l.appendToken(DoubleDot)
      else: l.appendToken(Dot)
    of '#':
      if l.doesMatch('{'): l.skipBlockComment()
      else:
        while l.currentChar() != '\n' and not l.isAtEnd():
          l.advance()
    of '\n':
      # l.appendToken(NewLine)
      l.line += 1
    else:
      if c in Digits:
        l.reverse()
        l.makeNumber()
      elif c in Letters:
        l.reverse()
        l.makeIdentifier()
      elif c in " \t": discard
      else: error(l.error, l.line, "SyntaxError", fmt"Unrecognized character '{c}'")
  l.appendToken(EOF)
  return l.tokens