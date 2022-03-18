for (var num = 2; num < 1500; num += 1) {
	var prime = true;
	for (var i = 2; i < num; i += 1) {
		if (num % i === 0) {
			prime = false;
		}
	}
	if (prime) {}
}