#
# objhash.nim
# SLAP
#
# Created by Nobuharu Shimazu on 3/3/2022
# 

import hashes, node, token, slaptype

# ------------------------- BASE TYPES --------------------------

method hash*(x: BaseType): Hash {.base.} = discard

method hash*(x: SlapInt): Hash = result = !$x.value.hash

method hash*(x: SlapFloat): Hash = result = !$x.value.hash

method hash*(x: SlapBool): Hash = result = !$x.value.hash

method hash*(x: SlapString): Hash = result = !$x.value.hash

method hash*(x: SlapList): Hash = result = !$x.values.hash

method hash*(x: SlapMap): Hash =
  result = x.map.hash
  result = !$result

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
  result = x.variable.hash !& x.indexOrKey.hash
  result = !$result

method hash*(x: AssignExpr): Hash =
  result = x.name.hash !& x.value.hash
  result = !$result

method hash*(x: ListOrMapAssignExpr): Hash =
  result = x.variable.hash !& x.indexOrKey.hash !& x.value.hash
  result = !$result

method hash*(x: SelfExpr): Hash =
  result = !$(x.keyword.hash)