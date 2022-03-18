## Classes

To create your own custom object in SLAP, you first need to define a class, using the keyword `class` just like many languages.
You can create your initializer using `new`.
```
class Car {
    new(color, style, brand) { # <-- Initializer
        self.color = color;
        self.brand = brand;
        &style = style; # alternatively, you can use `&` instead of `self.`
    }

    getColor() {
        return self.color;
    }
}

$blackMazda = Car("Black", "SUV", "Mazda");

println(blackMazda.getColor());
println(blackMazda.style);
blackMazda.color = "black";
println(blackMazda.color);
```
You can define static methods using `static` just before the method name.
```
class Math {
    static square(n) {
        return n * n;
    }
}

println(Math.square(3));
```
You can create a subclass by using the same `class` keyword but with the base class name annotated with `<-` keyword. (You see, I love arrows.)
```
class Car {
    drive() {
        print("driving");
    }
}

class Mazda <- Car {
    drive() {
        super.drive();
        println(" a Mazda");
    }
}
```

[next > Import Statement](https://github.com/bichanna/slap/blob/master/docs/syntax_doc/import.md#import-statement)
