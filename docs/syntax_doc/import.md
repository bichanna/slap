## Import Statement

You can import by using relative paths.


```
# A.slap
def greet(name) {
    println("Hello " + name + "!");
}
```
You can import like so:
```
# B.slap
import "A.slap";

greet("bichanna");
```

If you want to import particular variables, functions, or classes, you can do so by using `=>`.
```
import "std" => forEach;

let list = [1, 2, 3];

list -> forEach() <- def (x) => println(x);
```

[next > Syntax Sugars](https://github.com/bichanna/slap/blob/master/docs/syntax_doc/syntax_sugars.md#string-interpolation)
