## Functions

Functions in SLAP are declared using `define` and do not require their parameters and return types be annotated.
```
define greetStr(name) {
    return "Hello, " + name + "!";
}

println(greetStr("bichanna"));
```

Function arguments can have default values in SLAP. You can provide a default value to an argument by using `=`.
```
define greet(name="somebody") {
    println("Hello, " + name + "!");
}
greet();
# output: 'Hello, somebody!'
```

You can add `+` after parameter name if you are unsure about the number of arguments to pass in the functions.
```
import std;

define sum(list+) {
	let sum = 0;
	forEach(list) <- define(i) { sum += i; };
	return sum;
}

sum(3, 1, 4, 2, 5) -> println();
```

SLAP supports closures as well as passing functions.

```
define add(a, b) {
    return a + b;
}

define returnFunc(a) {
    return a;
}

println(returnFunc(add)(1, 4));
```

A function within a function looks like this:

```
define outerFunc() {
    define insideFunc() {
        println("I'm local.");
    }
    insideFunc();
}

outerFunc();
```

Here's an anonymous function example:

```
define doSomething(func) {
    func();
}

doSomething(define() {
    println("Hello World");
});
```

[next > Classes](https://github.com/bichanna/slap/blob/master/docs/syntax_doc/classes.md#classes)