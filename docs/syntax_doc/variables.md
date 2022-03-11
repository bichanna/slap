## Variables

Currently, SLAP only supports one variable type: `let` (I might add immutable `const` in the future), which is mutable. Alternatively, you can use `$`.

```
let name = "bichanna";
variable = "Nobuharu Shimazu";

$age = 15;
age = age + 1;
```

SLAP have usual assignment shorthands: `+=`, `-=`, `*=`, `/=`, `++` and `--`.
```
let num = 123;
num += 123;
num -= 321;
num *= 123;
num /= 321;
num++;
num--;
```

[next > Control Flow](https://github.com/bichanna/slap/blob/master/docs/syntax_doc/control_flow.md#control-flow)