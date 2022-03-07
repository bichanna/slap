<div align="center">
    <h1>The SLAP Programming Language</h1>
    |
    <a href="https://github.com/bichanna/slap/blob/master/docs/index.md#syntax">Doc</a>
    |
</div><br>

**WARNING!! THIS LANGUAGE IS IN DEVELOPMENT. ANYTHING CAN CHANGE AT ANY MOMENT.**

**SLAP** stands for **SL**ow **A**nd **P**owerless, but I hope to make it '**P**owerfull' someday.

**SLAP** is a dynamically- and strongly-typed, object-oriented programming language. Its syntax is a member of the C family; it is not meant to be groundbreaking but rather to feel similar with a bit of difference.

Here's an example SLAP program. ([samples](https://github.com/bichanna/slap/tree/master/lib))
```js
define binarySearch(list, target, low, high) {
  if (high >= low) {
    let mid = low + int((high - low) / 2);

    if (list@[mid] == target) {
      return mid;
    } elif (list@[mid] > target) {
      return binarySearch(list, target, low, mid - 1);
    } else {
      return binarySearch(list, target, mid + 1, high);
    }
  } else {
    return -1;
  }
}

let list = [1002, 1007, 1012, 1021, 1031, 1038, 1060, 1061, 1063, 1065, 1074, 1080, 1088, 1090, 1104, 1107, 1114, 1131, 1134, 1148, 1155, 1160, 1165, 1178, 1189, 1195, 1195, 1197, 1197, 1225, 1226, 1241, 1244];
let target = 1088;
let result = binarySearch(list, target, 0, len(list)-1);
println(result);
```
Here's another example using [`<-` and `->` expressions](https://github.com/bichanna/slap/blob/master/docs/index.md#--expression).
```rust
import math;

let num = 10;
(num -> math.abs() -> math.pow() <- num -> math.abs() -> math.sqrt()) -> println();
```


## TODO
[TODO list](https://github.com/bichanna/slap/blob/master/TODO.md)

## Installation
1. Download the source code from the releases page.
2. `cd` to the `src` directory and run the shell script (maybe need to do`chmod +x ./build.sh`).

## Contribution
Contributions are always welcome :D
