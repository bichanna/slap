<div align="center">
    <h1>The SLAP Programming Language</h1>
    |
    <a href="https://github.com/bichanna/slap/blob/master/docs/index.md#doc">Doc</a>
    |
</div><br>

<div align="center">
	
[![Ubuntu](https://github.com/bichanna/slap/actions/workflows/ubuntu.yml/badge.svg)](https://github.com/bichanna/slap/actions/workflows/ubuntu.yml)
[![macOS](https://github.com/bichanna/slap/actions/workflows/mac.yml/badge.svg)](https://github.com/bichanna/slap/actions/workflows/mac.yml)
	
</div>

**WARNING!! THIS LANGUAGE IS IN ACTIVE DEVELOPMENT. EVERTHING IS VERY UNSTABLE. ANYTHING CAN CHANGE AT ANY MOMENT.**

SLAP stands for "**SL**ow **A**nd **P**owerless." And I hope to make it "**P**owerful" someday.

**SLAP** is a dynamically- and strongly-typed, object-oriented programming language with a small portion of functional-language-like features. Its syntax is a member of the C family with a bit of difference.

Here's an example SLAP program. ([samples](https://github.com/bichanna/slap/tree/master/lib))
```js
import std;

let areas = ["tools", "game", "web", "science", "systems", "embedded", "drivers", "mobile", "GUI"];

std.forEach(areas) <- define(area) {
	println("Hello, $(area) developers!");
};
```
Here's another example using [`<-` and `->` expressions](https://github.com/bichanna/slap/blob/master/docs/syntax_doc/syntax_sugars.md#--expression).

```js
import math;

let num = 10;
(num -> abs() -> pow() <- num -> abs() -> sqrt()) -> println();
```

## Installation
On Linux/macOS, you may be able to run the following commands to install SLAP.
```
$ git clone https://github.com/bichanna/slap.git
$ cd slap
$ chmod +x ./build.sh 
$ ./build.sh
```
For Windows, I haven't written bat version of `build.sh`, so you have to manually compile the source code.
```
$ nimble build --multimethods:on -d:release
```
Then, mark it as an executable file if necessary, and try running `slap --version`.
```
$ slap --version
SLAP 0.0.3
```

You may want to test before running your SLAP programs.
```
$ nimble test
```

## TODO
>*Note:* If you have a feature request, please open an issue.

### Main
- [x] Basic Data Types
     - [x] Integer
     - [x] Float
     - [x] String
     - [x] Boolean
     - [x] Null
     - [x] List
     - [x] Map
 - [x] Basic Arithmetics
 - [x] Variables
 - [x] If Statements
     - [x] elif
     - [x] else
 - [x] While Loops
 - [x] For Loops
     - [x] Break
     - [x] Continue
     - [x] "Enhanced" for loop (in the form of `forEach`)
 - [ ] Try-except Blocks
 - [x] Functions
     - [x] Lambdas (anonymous functions)
     - [x] Default Arguments
     - [x] Rest Parameters
 - [x] Standard Library
     - [x] Std
     - [x] Str
     - [ ] OS
     - [ ] I/O interfaces
     - [x] Math
     - [ ] Networking
 - [x] Classes
 - [x] Import
 - [ ] Concurrency
### Others
 - [x] Assignment Shorthands (e.g, `+=`, `*=`)
 - [x] String Interpolation
 - [ ] Optional Type Annotations
 - [x] Multi-line Comments

## Contribution
Contributions are always welcome :)<br>
Please be sure to add test files if you add new features (see [tests directory](https://github.com/bichanna/slap/tree/master/tests#tests) for more info).


## Credits
I learned a lot from
 - [Oak language](https://github.com/thesephist/oak) by thesephist
 - Bob Nystrom's great book, [*Crafting Interpreters*](https://craftinginterpreters.com/).
