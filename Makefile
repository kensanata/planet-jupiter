README.md: jupiter.pl
	pod2markdown $< $@

clean:
	rm -rf test-*

jobs ?= 4

test: clean
	prove -j $(jobs) t

