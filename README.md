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

**WARNING!! THIS LANGUAGE IS IN ACTIVE DEVELOPMENT. ANYTHING CAN CHANGE AT ANY MOMENT. AND EVERTHING IS VERY FRAGILE & UNSTABLE.**

**SLAP** stands for **SL**ow **A**nd **P**owerless, but I hope to make it '**P**owerfull' someday.

**SLAP** is a dynamically- and strongly-typed, object-oriented programming language. Its syntax is a member of the C family with a bit of difference.

Here's an example SLAP program. ([samples](https://github.com/bichanna/slap/tree/master/lib))
```js
import std;
let areas = ["tools", "GUI", "game"];
forEach(areas) <- define(area) {
	println("Hello, $(area) developers!");
};
```
Here's another example using [`<-` and `->` expressions](https://github.com/bichanna/slap/blob/master/docs/index.md#--expression).

```js
import math;

let num = 10;
(num -> abs() -> pow() <- num -> abs() -> sqrt()) -> println();
```

## Installation
```
git clone https://github.com/bichanna/slap.git
cd slap
chmod +x ./build.sh 
./build.sh
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
     - [ ] Continue
     - [x] "Enhanced" for loop (in the form of `forEach`)
 - [ ] Try-except Blocks
 - [x] Functions
     - [x] Lambdas (anonymous functions)
     - [x] Default Arguments
     - [ ] Rest Parameters
 - [x] Standard Library
     - [x] Basic (e.g., `println`, `print`)
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
