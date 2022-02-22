> *Note:* I'm not sure why Julia is slower than Python... Please check my code.

I used these commands:
```
python3 benchmark/fib/python3.py # 3.9.10
julia benchmark/fib/julia.jl     # 1.7.1
node benchmark/fib/javascript.js # 14.16.0
slap benchmark/fib/slap.slap	 # None
```

### Fibonacci Sequence
| Language  | Time |
| --------- | ---- |
| JavaScript| 0.07s|
| Python    | 0.07s|
| Julia     | 0.22s|
| SLAP	    | 0.63s|


### Prime Numbers
| Language  | Time |
| --------- | ---- |
| JavaScript| 0.07s|
| Python    | 0.17s|
| Julia     | 0.32s|
| SLAP	    | 2.25s|