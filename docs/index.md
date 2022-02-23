# SLAP

SLAP is a dynamically and strongly typed, object-oriented programming language with the syntax of the C family.<br>
SLAP's syntax is ordinary; it is not meant to be groundbreaking but rather to feel similar with a little bit of difference.

## Syntax

### Hello World
The code for a hello world program in SLAP is as follows:
```
writeln("Hello World!");
```

### Comments
Comments in SLAP begin with the hash character.
```
# This is a comment
writeln("This will be printed"); # Another comment
```

### Data Types
> *Note:* NYI stands for "Not Yet Implemented"
 - String
 - Int
 - Float
 - Bool
 - Null
 - Array (NYI)
 - Map (NYI)
```
"A string";   # string
123;          # int
12.3;         # float
true; false;  # bool
null;         # null
```

### Variables
Currently, SLAP only supports one variable type: `let`, which is mutable.<br>
> *Note:* `const` type will be added in the future.
```
let variable = "Some string";
variable = 123;
```

### Control Flow
> *Note:* `elif` is not yet available but will be added soon.

An `if` statement executes one of two statements based on some condition.
```
if (i < 10) {
    writeln("smaller than 10");
} else {
    writeln("bigger than 10");
}

# here's one-line if
if (i < 10) writeln("smaller than 10");
```

A `while` loop is just like many other languages.
```
let i = 1;
while (i < 10) {
    writeln(i);
    i = i + 1;
}
```

A `for` loop looks like this (crude):
```
for (let i = 1; i < 10; i = i + 1) {
    writeln(i);
}
```

### Functions
SLAP supports first class functions.<br>
A normal function looks like this:
```
define greetStr(name) {
    return "Hello, " + name + "!";
}

writeln(greetStr("bichanna"));
```
SLAP supports closures as well as passing functions.
```
define add(a, b) {
    return a + b;
}

define returnFunc(a) {
    return a;
}

writeln(returnFunc(add)(1, 4));
```
A function within a function looks like this:
```
define outerFunc() {
    define insideFunc() {
        writeln("I'm local.");
    }
    insideFunc();
}

outerFunc();
```

### Classes
> *Note:* Will be added soon.


