#
# test.nim
# SLAP
#
# Created by Nobuharu Shimazu on 3/10/2022
# 

import os, sugar, osproc, strformat, terminal

# This piece of code gets all the test files in `tests` directory
let tests = collect(newSeq):
  for path in walkFiles("tests/*/*.slap"): path


# This proc extracts the expected output from the test file
# and returns it
proc extractOutput(path: string): string =
  var source = readFile(path)
  var current = 0
  var c: char
  var inside = false
  var nxt: char
  var returnValue = ""

  while current < source.len:
    c = source[current]
    if current+1 < source.len: nxt = source[current+1]
    else: nxt = '\0'
    if c == '#' and nxt == '{':
      current += 2
      inside = true
    elif c == '}' and nxt == '#': break
    elif inside: returnValue &= $c
    current += 1
  
  return returnValue


# This executes every test files and tests if each test
# file worked properly by checking the output.
for path in tests:
  var expectedOutput = extractOutput(path)
  let (output, _) = execCmdEx(fmt"slap --test {path}")
  if expectedOutput != output:
    echo "Expected output:\n" & expectedOutput
    echo "Actual output:\n" & output
    quit(path & " <- this file causes an error\n\n", 1)
  else:
    styledEcho(fgGreen, fmt"Test passed: {path}")
