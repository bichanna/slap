People seem to like benchmarks, so here they are.

As of March 2022, SLAP is approximately 7-8x slower than Python 3.9. That's decently fast for a tree-walker.

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
| Python    | 0.09s|
| Julia     | 0.11s|
| SLAP	    | 0.58s|


### Prime Numbers
| Language  | Time |
| --------- | ---- |
| JavaScript| 0.07s|
| Python    | 0.13s|
| Julia     | 0.28s|
| SLAP	    | 1.88s|


## Bubble Sort
| Language  | Time |
| --------- | ---- |
| JavaScript| 0.06s|
| Python    | 0.18s|
| Julia     | 0.27s|
| SLAP	    | 2.37s|
