# About SLAP
SLAP stands for "**SL**ow **A**nd **P**owerless". And I hope to make it "**P**owerfull" someday.

SLAP is a dynamically- and strongly-typed, object-oriented programming language. Its syntax is a member of the C family with a bit of difference.

# How slow is SLAP?
You can see the benchmarks [here](https://github.com/bichanna/slap/tree/master/benchmark#readme).

# Syntax
> *Note:* NYI stands for "Not Yet Implemented"<br>

## Hello World
The code for a hello world program in SLAP is as follows:
```
println("Hello World!");
```

## Comments
Comments in SLAP begin with the hash character.
```
# This is a comment
println("This will be printed"); # Another comment
```
Multi-line or block comments begin with the hash and curly bracket, `#{`, and are terminated with a closing curly bracket followed by a hash, `}#`. Multi-line comments can be nested.
```
#{
    This is a block comment.
    #{ I'm nested. }#
}#
```

## Data Types
> *Note:* For the syntax sugar I used in the examples, see ['Syntax Sugars'](https://github.com/bichanna/slap/blob/master/docs/index.md#syntax-sugars)<br>
> *Note:* SLAP list uses @[] instead of [] unlike many languages. (e.g., `list@[0]`, not `list[0]`)

 - String
 - Int
 - Float
 - Bool
 - Null
 - List
 - Map

```
"A string";   # string
123;          # int
12.3;         # float
true; false;  # bool
null;         # null

let anotherList = [1, 2, "string", 3.1415]; # using list literal (faster)
anotherList -> append("Hello World");
anotherList@[0] = 2.7;
let anotherPoppedItem = pop(anotherList);
anotherList -> append(len(anotherList));
println(anotherList@[0]);

let map = {"key": "secret value", "another key": 123445}; # map
map@["key"] = "some value";
println(map);
```

## Variables

Currently, SLAP only supports one variable type: `let`, which is mutable. Alternatively, you can use `$`.
> *Note:* `const` type will be added in the future.

```
let variable = "Some string";
variable = 123;

$age = 15;
age = age + 1;
```

## Control Flow

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
You can also use just one line for an if statement (you can use this for many other things in SLAP).
```
if (i < 10) println("smaller than 10");
```

A `while` loop is just like many other languages.
```
let i = 1;
while (i < 10) {
    println(i);
    i = i + 1;
}
```

A `for` loop looks like this:
```
for ($i = 1; i < 10; i = i + 1) {
    println(i);
}
```

## Functions

Functions in SLAP are declared using `define` and do not require their parameters and return types be annotated.
```
define greetStr(name) {
    return "Hello, " + name + "!";
}

println(greetStr("bichanna"));
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

## Classes

To create your own custom object in SLAP, you first need to define a class, using the keyword `class` just like many languages.
You can create your initializer using `new`.
```
class Car {
    new(color, style, brand) { # <-- Initializer
        self.color = color;
        self.brand = brand;
        &style = style; # alternatively, you can use `&` instead of `self.`
    }

    getColor() {
        return self.color;
    }
}

$blackMazda = Car("Black", "SUV", "Mazda");

println(blackMazda.getColor());
println(blackMazda.style);
blackMazda.color = "black";
println(blackMazda.color);
```
You can define static methods using `static` just before the method name.
```
class Math {
    static square(n) {
        return n * n;
    }
}

println(Math.square(3));
```
You can create a subclass by using the same `class` keyword but with the base class name annotated with `<-` keyword. (You see, I love arrows.)
```
class Car {
    drive() {
        println("driving");
    }
}

class Mazda <- Car {
    drive() {
        super.drive("Mazda");
    }
}
```

## Import Statement
A module is a file containing SLAP definitions and statements. The file name is the module name with the suffix `.slap` appended.
```
# A.slap
define greet(name) {
    println("Hello " + name + "!");
}
```
You can import like so:
```
# B.slap
import A;

greet("bichanna");
```

# Syntax Sugars

## `<-` Expression
Because I like callbacks, there's special syntax sugar, the `<-` expression. The `<-` syntax sugar de-sugars like this:
```
someFunc("abc") <- define(data) {
    println(data);
};

someFunc("abc", define(data) {  # de-sugars to this
    println(data);
});
```

## `->` Expression
I don't like this syntax: `append(list, "bichanna");`, so I decided to create this special syntax sugar, the `->` expression.<br>
(⚠️ It's not like C's `->`!)
```
list -> append("bichanna");

append(list, "bichanna"); # de-sugars to this
```
Here's an example using both `<-` and `->` expressions.
```
(num -> abs() -> pow() <- num -> abs() -> sqrt()) -> println();
println(pow(abs(num), sqrt(abs(num)))); # de-sugars to this
```
