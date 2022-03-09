<div align="center">
    <h1>The SLAP Programming Language</h1>
    |
    <a href="https://github.com/bichanna/slap/blob/master/docs/index.md#syntax">Doc</a>
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
let areas = ["tools", "science", "GUI", "game"];
forEach(areas) <- define(area) {
	println("Hello, " + area + " developers!");
};
```
Here's another example using [`<-` and `->` expressions](https://github.com/bichanna/slap/blob/master/docs/index.md#--expression).

```js
import math;

let num = 10;
(num -> abs() -> pow() <- num -> abs() -> sqrt()) -> println();
```

## TODO
[TODO list](https://github.com/bichanna/slap/blob/master/TODO.md)

## Installation
1. Download the source code from the releases page.
2. `cd` to the `src` directory and run the shell script (maybe need to do`chmod +x ./build.sh`).

## Contribution
Contributions are always welcome :D
