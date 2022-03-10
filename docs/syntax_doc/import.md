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