#
# token.nim
# SLAP
#
# Created by Nobuharu Shimazu on 2/15/2022
# 

import std/strformat, strutils

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
    Minus               = "MINUS" # -
    Tilde               = "TILDE" # ~
    Star                = "STAR" # *
    Modulo              = "MODULO" # %
    Slash               = "SLASH" # /
    Pound               = "POUND" # #
    At                  = "AT" # @
    Caret               = "CARET" # ^
    Comma               = "COMMA" # ,
    Bang                = "BANG" # !
    LeftArrow           = "LEFT_ARROW" # <-
    RightArrow          = "RIGHT_ARROW" # ->
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
    Define              = "define"
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

  Token* = object
    kind*: TokenType
    value*: string
    line*: int

proc `$`*(token: Token): string =
  return fmt"{token.kind}:{token.value}:{token.line}"