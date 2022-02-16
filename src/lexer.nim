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