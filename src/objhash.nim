#
# objhash.nim
# SLAP
#
# Created by Nobuharu Shimazu on 3/3/2022
# 

import hashes, node, token

# ---------------------------- TOKEN ----------------------------

proc hash*(x: Token): Hash =
  result = x.kind.hash !& x.value.hash !& x.line.hash
  result = !$result

# ---------------------------- NODES ----------------------------

method hash*(x: Expr): Hash {.base.} = discard

method hash*(x: VariableExpr): Hash =
  result = x.name.hash
  result = !$result

method hash*(x: ListOrMapVariableExpr): Hash =
  result = x.name.hash !& x.indexOrKey.hash
  result = !$result

method hash*(x: AssignExpr): Hash =
  result = x.name.hash !& x.value.hash
  result = !$result

method hash*(x: ListOrMapAssignExpr): Hash =
  result = x.name.hash !& x.indexOrKey.hash !& x.value.hash
  result = !$result

method hash*(x: SelfExpr): Hash =
  result = !$(x.keyword.hash)