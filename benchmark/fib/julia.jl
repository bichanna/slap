function fib(n)
	if n <= 1
		return n
	end
	return fib(n - 2) + fib(n - 1)
end

for i in 0:24
	fib(i)
end