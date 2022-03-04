# SLAP
SLAP stands for **Sl**ow **A**nd **P**owerless. And I hope to make it '**P**owerfull' someday.<br>
SLAP is a dynamically and strongly typed, object-oriented programming language with the syntax of the C family.<br>
SLAP's syntax is ordinary; it is not meant to be groundbreaking but rather to feel similar with a little bit of difference.

## Benchmark
SLAP's slow as you can see the benchmark [here](https://github.com/bichanna/slap/tree/master/benchmark#readme).

## Syntax

### Hello World
The code for a hello world program in SLAP is as follows:
```
println("Hello World!");
```

### Comments
Comments in SLAP begin with the hash character.
```
# This is a comment
println("This will be printed"); # Another comment
```

### Data Types
> *Note:* NYI stands for "Not Yet Implemented"<br>
> *Note:* For the syntax sugar I used in the examples, see ['Syntax Sugars'](https://github.com/bichanna/slap/blob/master/docs/index.md#syntax-sugars)
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

let list = List([1, 2, "string", 3.1415]); # using List class (slower)
list.append("Hello World");
list.set(0, 2.7);
let poppedItem = list.pop();
list.append(list.len);
println(list.get(0));

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

### Variables

Currently, SLAP only supports one variable type: `let`, which is mutable. Alternatively, you can use `$`.
> *Note:* `const` type will be added in the future.

```
let variable = "Some string";
variable = 123;

$age = 15;
age = age + 1;
```

### Control Flow

An `if` statement executes one of multiple statements based on some conditions.
```
if (name == "Nobuharu") {
    println("What a cool name!");
} elif (name == "bichanna") {
    println("How fabulous!");
} else {
    println("Hi " + name + "!");
}
```
You can also use just one line for an if statement.
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

A crude `for` loop looks like this:
```
for ($i = 1; i < 10; i = i + 1) {
    println(i);
}
```

### Functions
SLAP supports first class functions.<br>
A normal function looks like this:
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

### Classes
> *Note:* Inheritance is not yet implemented.

A class looks like this:
```
class Car {
    new(color, style, brand) {
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
You can also define static methods:
```
class Math {
    static square(n) {
        return n * n;
    }
}

println(Math.square(3));
```
Here's how a class inherits another class:
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

### Module System (NYI)

## Syntax Sugars

### `<-` Expression

Because I like callbacks, there's special syntax sugar, the `<-` expression. The `<-` syntax sugar de-sugars like this:
```
someFunc("abc") <- define(data) {
    println(data);
};

someFunc("abc", define(data) {  # de-sugars to this
    println(data);
})
```

### `->` Expression
I also didn't like this syntax: `append(list, "bichanna");`, I decided to create this special syntax sugar, the `->` expression.
```
list -> append("bichanna");

append(list, "bichanna"); # de-sugars to this
```