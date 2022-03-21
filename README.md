<div align="center">
    <h1>The SLAP Programming Language</h1>
    |
    <a href="https://github.com/bichanna/slap/blob/master/docs/index.md#doc">Doc</a>
    |
</div><br>

<div align="center">
	
[![Ubuntu](https://github.com/bichanna/slap/actions/workflows/ubuntu.yml/badge.svg)](https://github.com/bichanna/slap/actions/workflows/ubuntu.yml)
[![macOS](https://github.com/bichanna/slap/actions/workflows/mac.yml/badge.svg)](https://github.com/bichanna/slap/actions/workflows/mac.yml)
[![Windows](https://github.com/bichanna/slap/actions/workflows/windows.yml/badge.svg)](https://github.com/bichanna/slap/actions/workflows/windows.yml)
	
</div>

**WARNING!! THIS LANGUAGE IS IN ACTIVE DEVELOPMENT. ANYTHING CAN CHANGE AT ANY MOMENT.**

🖐 SLAP stands for "**SL**ow **A**nd **P**owerless." And I hope to make it "**P**owerful" someday (though it is mostly for my learning).

**SLAP** is a dynamically- and strongly-typed, object-oriented programming language with a small portion of functional-language-like features. Its syntax is a member of the C family with a bit of difference.

As of March 2022, you can write pretty decent small programs in SLAP.

Here's an example SLAP program. ([samples & libs](https://github.com/bichanna/slap/tree/master/lib))
```js
import "std" => forEach;

let areas = ["tools", "game", "web", "science", "systems", "embedded", "drivers", "mobile", "GUI"];

areas -> forEach() <- def (area) => println("Hello, ${area} developers!");
```
Here's another example using [`<-` and `->`](https://github.com/bichanna/slap/blob/master/docs/syntax_doc/syntax_sugars.md#--expression) expressions intensively.

```py
import "math";

let num = 10;

(num -> abs() -> pow() <- num -> abs() -> sqrt()) -> println();
# same as below
# println(pow(abs(num), sqrt(abs(num))));
```

## Installation
On Linux/macOS, you may be able to run the following commands to install SLAP.
```
$ git clone https://github.com/bichanna/slap.git
$ cd slap
$ chmod +x ./build.sh 
$ ./build.sh         # SLAP Vim highlighter automatically gets installed
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

You may want to test current SLAP you just built before running your programs.
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
     - [x] String
     - [x] OS
     - [x] I/O interfaces
     - [x] Math
     - [ ] Networking
 - [x] Classes
     - [x] Class Methods
     - [x] Inheritance
     - [ ] Abstract Class (Interface)
 - [x] Import
 - [ ] Concurrency
### Others
 - [x] Assignment Shorthands (e.g, `+=`, `*=`)
 - [x] String Interpolation
 - [ ] Optional Type Annotations
 - [x] Multi-line Comments
 - [x] Vim Highlighter
 - [ ] VSCode Highlighter
 - [ ] Sublime Text Highlighter

## Contribution
Bug reports and contributions are always welcome :)<br>
Please be sure to add test files if you want to add new features (see [tests directory](https://github.com/bichanna/slap/tree/master/tests#tests) for more info).


## Credits
I learned a lot from
 - [Oak language](https://github.com/thesephist/oak) by [thesephist](https://github.com/thesephist)
 - [Bob Nystrom](https://github.com/munificent)'s great book, [*Crafting Interpreters*](https://craftinginterpreters.com/).
