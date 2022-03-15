## Import Statement
> *Note:* The SLAP module system will be updated soon.

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

A.greet("bichanna");
```
You can use `->` like `as` keyword in Python.
```
import A -> a;
```

[next > Syntax Sugars](https://github.com/bichanna/slap/blob/master/docs/syntax_doc/syntax_sugars.md#--expression)
