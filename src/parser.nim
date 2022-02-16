#
# parser.nim
# SLAP
#
# Created by Nobuharu Shimazu on 2/17/2022
#

import token, error, node

type
  # Parser takes in a list of tokens (seq[Token]) and 
  # returns an abstract syntax tree.
  Parser* = object
    error*: Error
    tokens*: seq[Token]
    current*: int
    