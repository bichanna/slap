function fib(n) {
	if (n <= 1) {
		return n;
	}
	return fib(n - 2) + fib(n - 1);
}

for (var i = 0; i < 25; i += 1) {
	fib(i)
}