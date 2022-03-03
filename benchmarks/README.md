> *Note:* I'm not sure why Julia is slower than Python... Please check my code.

Commands used:
```
time python3 benchmark/fib/python3.py # 3.9.10
time julia benchmark/fib/julia.jl     # 1.7.1
time node benchmark/fib/javascript.js # 14.16.0
time slap benchmark/fib/slap.slap     # None
```

### Fibonacci Sequence
| Language  | Time |
| --------- | ---- |
| JavaScript| 0.07s|
| Python    | 0.07s|
| Julia     | 0.11s|
| SLAP	    | 0.52s|


### Prime Numbers
| Language  | Time |
| --------- | ---- |
| JavaScript| 0.07s|
| Python    | 0.17s|
| Julia     | 0.32s|
| SLAP	    | 1.97s|


## Bubble Sort
|       Language    | Time |
| ----------------- | ---- |
|     JavaScript    | 0.05s|
|       Python      | 0.19s|
|        Julia      | 0.23s|
| SLAP(list literal)| 3.20s|
| SLAP(ListClass)   | 6.44s|