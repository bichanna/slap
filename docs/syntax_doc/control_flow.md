## Control Flow

### If Statements
An `if` statement executes one of multiple statements based on some conditions. However, SLAP does not use an `else if` construct like many languages; it uses a more condensed `elif`.
```
if (name == "Nobuharu") {
    println("What a cool name!");
} elif (name == "bichanna") {
    println("How fabulous!");
} else {
    println("Hi " + name + "!");
}
```
You can also use just one line for an if statement (this can also be done with `for` and `while`).
```
if (i < 10) println("smaller than 10");
```

### While Statements
A `while` loop works just like many other languages.
```
let i = 1;
while (i < 10) {
    println(i);
    i = i + 1;
}
```

### For Statements
A `for` loop looks like this:
```
for ($i = 1; i < 10; i++) {
    println(i);
}
```

### `forEach` Function
SLAP has an "enhanced" for loop, in the form of `forEach` function.
```
import std; # we'll talk about import statements later.

let list = ["game", "GUI", "web"]

forEach(list) <- def (i) { # we'll talk about functions, `<-`, and `->` expressions.
	println("Hello, " + i + " developers!");
}
```

[next > Functions](https://github.com/bichanna/slap/blob/master/docs/syntax_doc/functions.md#functions)
