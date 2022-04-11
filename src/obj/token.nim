#
# token.nim
# SLAP
#
# Created by Nobuharu Shimazu on 2/15/2022
# 

import std/strformat, strutils

var sourceId*: int16 = 0;

type
  TokenType* = enum
    Int                 = "INT"
    Float               = "FLOAT"
    String              = "STRING"
    Identifier          = "IDENTIFIER"
    LeftParen           = "LEFT_PAREN" # (
    RightParen          = "RIGHT_PAREN" # )
    LeftBrace           = "LEFT_BRACE" # {
    RightBrace          = "RIGHT_BRACE" # }
    LeftBracket         = "LEFT_BRACKET" # [
    RightBracket        = "RIGHT_BRACKET" # ]
    Colon               = "COLON" # :
    SemiColon           = "SEMICOLON" # ;
    Plus                = "PLUS" # +
    PlusPlus            = "PLUS_PLUS" # ++
    PlusEqual           = "PLUS_EQUAL" # +=
    Minus               = "MINUS" # -
    MinusMinus          = "MINUS_MINUS" # --
    MinusEqual          = "MINUS_EQUAL" # -=
    Tilde               = "TILDE" # ~
    Star                = "STAR" # *
    StarEqual           = "STAR_EQUAL" # *=
    Modulo              = "MODULO" # %
    Slash               = "SLASH" # /
    SlashEqual          = "SLASH_EQUAL" # /=
    Pound               = "POUND" # #
    At                  = "AT" # @
    Caret               = "CARET" # ^
    Comma               = "COMMA" # ,
    Bang                = "BANG" # !
    LeftArrow           = "LEFT_ARROW" # <-
    RightArrow          = "RIGHT_ARROW" # ->
    FatRightArrow       = "FAT_RIGHT_ARROW" # =>
    Equals              = "EQUALS" # =
    EqualEqual          = "EQUAL_EQUAL" # ==
    GreaterEqual        = "GREATER_THAN_OR_EQUAL" # >=
    Greater             = "GREATER_THAN" # >
    LessEqual           = "LESS_THAN_OR_EQUAL" # <=
    Less                = "LESS_THAN" # <
    BangEqual           = "BANG_EQUAL" # !=
    NewLine             = "NEW_LINE" # \n
    DoubleDot           = "DOUBLE_DOT" # .
    Dot                 = "DOT" # .
    EOF                 = "EOF"

    # keywords
    Define              = "def"
    Class               = "class"
    Static              = "static"
    And                 = "and"
    Let                 = "let"
    Const               = "const"
    Or                  = "or"
    If                  = "if"
    Elif                = "elif"
    Else                = "else"
    For                 = "for"
    Super               = "super"
    While               = "while"
    Self                = "self"
    Return              = "return"
    Continue            = "continue"
    Break               = "break"
    True                = "true"
    False               = "false"
    Null                = "null"
    Import              = "import"

  Token* = ref object of RootObj
    kind*: TokenType
    value*: string
    line*: int
    sId*: int8

proc newToken*(kind: TokenType, value: string, line: int): Token =
  return Token(kind: kind, value: value, line: line, sId: int8(sourceId))

proc `$`*(token: Token): string =
  return fmt"{token.kind}:{token.value}:{token.line}"