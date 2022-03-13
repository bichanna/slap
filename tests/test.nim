#
# test.nim
# SLAP
#
# Created by Nobuharu Shimazu on 3/10/2022
# 

import os, sugar, osproc, strformat

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
var errors: seq[seq[string]] = @[]
for path in tests:
  var expectedOutput = extractOutput(path)
  let (output, _) = execCmdEx(fmt"slap --test {path}")
  if expectedOutput != output:
    errors.add(@[
      "------------------\nfilename: " & path,
      "\nExpected output:\n" & expectedOutput,
      "Actual output:\n" & output & "\n------------------"
    ])
    stdout.write("F")
  else:
    stdout.write(".")


# After running all the files, show errors if there's any.
stdout.write("\n\n")
if errors.len == 0:
  quit(0)
else:
  for err in errors:
    for i in err: echo i
  quit(1)