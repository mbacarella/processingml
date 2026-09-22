.PHONY: all build serve clean

all: build


build:
	./build.sh

clean:
	dune clean
	rm -f static/toplevel.js
