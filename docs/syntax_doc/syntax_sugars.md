## String Interpolation
You can use string interpolation in SLAP by using `${...}`.
```
println("3 time 4 is ${3 * 4}");
```
SLAP de-sugars the above code to this:
```
println("3 times 4 is " + (3 * 4) + "");
```

## `<-` Expression
Because I like callbacks, there's special syntax sugar, the `<-` expression. The `<-` syntax sugar de-sugars like this:
```
someFunc("abc") <- def (data) {
    println(data);
};

someFunc("abc", def (data) {  # de-sugars to this
    println(data);
});
```

## `->` Expression
I don't like this syntax: `append(list, "bichanna");`, so I decided to create this special syntax sugar, the `->` expression.<br>
(⚠️ It's not like C's `->`!)
```
list -> append("bichanna");

append(list, "bichanna"); # de-sugars to this
```
Here's an example using both `<-` and `->` expressions.
```
(num -> abs() -> pow() <- num -> abs() -> sqrt()) -> println();
println(pow(abs(num), sqrt(abs(num)))); # de-sugars to this
```
