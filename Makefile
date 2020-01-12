README.md: jupiter.pl
	pod2markdown $< $@

clean:
	rm -rf test-*

test:
	prove t
