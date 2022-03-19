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

[next > Syntax Sugars](https://github.com/bichanna/slap/blob/master/docs/syntax_doc/syntax_sugars.md#string-interpolation)
