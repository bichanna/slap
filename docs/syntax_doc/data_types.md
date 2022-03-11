## Data Types
> *Note:* For the syntax sugar I used in the examples, see ['Syntax Sugars'](https://github.com/bichanna/slap/blob/master/docs/index.md#syntax-sugars)<br>
> *Note:* SLAP list uses @[] instead of [] unlike many languages. (e.g., `list@[0]`, not `list[0]`)

 - String
 - Int
 - Float
 - Bool
 - Null
 - List
 - Map

### String
String are enclosed in double quotes (`"..."`).
```
"This is a string"
```

### Numbers
The integer numbers (e.g., 2, 4, and 20) have type `int`, the ones with a fractional part (e.g., 5.0, and 1.6) have type `float`.
```
123; # this is an int
3.1415 # this is a float
```

### Boolean
SLAP has a dedicated Boolean type unlike some ancient languages.
There are two Boolean values and a literal for each one.
```
true; false;
```

### Null
`null` represents "no value" or "nothing".
```
null;
```

### List
Lists are used to store multiple items in a single variable just like many other languages.
```
[1, 1.234, "bichanna", ["a", "b", "c"], {"key": "value"}];
```
SLAP list uses `@[]` instead of `[]` unlike many languages. (e.g., `list@[0]`, not `list[0]`)
```
let list = ["some string", 321];

list@[0] = "Anna";

println(list);
```
Examples:
```
let list = [1, 2, "string", 3.1415];

list -> append("Hello World");

list@[0] = 2.7;

let poppedItem = pop(list);

list -> append(len(list));

println(list@[0]);
```

### Map
Unlike lists, which are indexed by a range of numbers, dictionaries are indexed by keys, which can be any immutable type.
```
let map = {"key": "value", "E": 2.71828};

println(map@["E"]);
```
Examples:
```
let map = {"key": "secret value", 321: 123445};

map@["key"] = "some value";

println(map->keys());
println(map->values());
```

[next > Variables](https://github.com/bichanna/slap/blob/master/docs/syntax_doc/variables.md#variables)
