#
# interpreterObj.nim
# SLAP
#
# Created by Nobuharu Shimazu on 2/28/2022
#

import env, slaptype, error, node
import tables

type
  # Interpreter takes in an abstract syntax tree and executes
  Interpreter* = object
    error*: Error
    env*: Environment
    globals*: Environment
    exprSeqForLocals*: seq[Expr]
    locals*: Table[int, int]
  
  FuncType* = ref object of BaseType
    call*: proc (self: var Interpreter, args: seq[BaseType]): BaseType
    arity*: proc (): int
  
  Function* = ref object of FuncType
    isInitFunc*: bool
    declaration*: FuncStmt
    closure*: Environment

  ClassType* = ref object of FuncType
    name*: string
    methods*: Table[string, Function]
    cinstance*: ClassInstance
    superclass*: ClassType

  ClassInstance* = ref object of BaseType
    class*: ClassType
    fields*: Table[string, BaseType]

  ListInstance* = ref object of ClassInstance
    elements*: seq[BaseType]