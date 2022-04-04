#
# codegen.nim
# SLAP
#
# Created by Nobuharu Shimazu on 4/2/2022
#

import node

const
  StaticError = "StaticError"

type
  # This enum specifies the target language which SLAP is compiled to.
  # Currently, SLAP supports only JavaScript as a target language.
  TargetLang* = enum
    JAVASCRIPT,
    # CPP,
    # C,

  # CodeGenerator takes in an abstract syntax tree and tanspile to
  # the target language (currenlty, only JS is available).
  CodeGenerator* = object
    ast: seq[Stmt]
    language: TargetLang


