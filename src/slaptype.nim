#
# slaptype.nim
# SLAP
#
# Created by Nobuharu Shimazu on 2/18/2022
#

import tables

type
  # SLAP types
  BaseType* = ref object of RootObj

  SlapString* = ref object of BaseType
    value*: string

  SlapInt* = ref object of BaseType
    value*: int64

  SlapFloat* = ref object of BaseType
    value*: float64

  SlapBool* = ref object of BaseType
    value*: bool

  SlapList* = ref object of BaseType
    values*: seq[BaseType]

  SlapMap* = ref object of BaseType
    map*: Table[BaseType, BaseType]

  SlapNull* = ref object of BaseType

proc newString*(value: string): SlapString = return SlapString(value: value)

proc newInt*(value: int64): SlapInt = return SlapInt(value: value)

proc newFloat*(value: float64): SlapFloat = return SlapFloat(value: value)

proc newBool*(value: bool): SlapBool = return SlapBool(value: value)

proc newList*(values: seq[BaseType]): SlapList = return SlapList(values: values)

proc newMap*(map: Table[BaseType, BaseType]): SlapMap = return SlapMap(map: map)

proc newNull*(): SlapNull = return SlapNull()