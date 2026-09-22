.PHONY: all build serve clean

all: build

build:
	./build.sh

# Any static file server will do; the page also opens straight from file://.
serve: build
	python3 -m http.server -d static 8000

clean:
	dune clean
	rm -f static/toplevel.js
