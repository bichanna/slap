## Functions

Functions in SLAP are declared using `def` and do not require their parameters and return types be annotated.
```
def greetStr(name) {
    return "Hello, " + name + "!";
}

println(greetStr("bichanna"));
```

Function arguments can have default values in SLAP. You can provide a default value to an argument by using `=`.
```
def greet(name="somebody") {
    println("Hello, " + name + "!");
}
greet();
# output: 'Hello, somebody!'
```

You can add `+` after parameter name if you are unsure about the number of arguments to pass in the functions.
```
import std;

def sum(list+) {
	let sum = 0;
	forEach(list) <- def (i) { sum += i; };
	return sum;
}

sum(3, 1, 4, 2, 5) -> println();
```

SLAP supports closures as well as passing functions.

```
def add(a, b) {
    return a + b;
}

def returnFunc(a) {
    return a;
}

println(returnFunc(add)(1, 4));
```

A function within a function looks like this:

```
def outerFunc() {
    def insideFunc() {
        println("I'm local.");
    }
    insideFunc();
}

outerFunc();
```

Here's an anonymous function example:

```
def doSomething(func) {
    func();
}

doSomething(def() => {
    println("Hello World");
});
```

[next > Classes](https://github.com/bichanna/slap/blob/master/docs/syntax_doc/classes.md#classes)