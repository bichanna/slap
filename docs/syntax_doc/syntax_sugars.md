## `<-` Expression
Because I like callbacks, there's special syntax sugar, the `<-` expression. The `<-` syntax sugar de-sugars like this:
```
someFunc("abc") <- define(data) {
    println(data);
};

someFunc("abc", define(data) {  # de-sugars to this
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