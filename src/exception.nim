#
# exception.nim
# SLAP
#
# Created by Nobuharu Shimazu on 2/21/2022
# 

import slaptype

type
  # ReturnException is used to unwind all the way
  # down to the body of the function
  ReturnException* = ref object of Exception
    value*: BaseType