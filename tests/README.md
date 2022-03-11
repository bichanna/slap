## Tests

The `test.nim` automatically extracts expected outputs from block comments (`#{...}#`), which each test file contains, and checks if the actual output and the expected output match.

Example:
```
# Check arithmetic

let num = 123;
println(num * 2);

#{
246
}#
```