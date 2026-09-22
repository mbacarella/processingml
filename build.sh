#!/bin/sh
# Build static/toplevel.js: an OCaml toplevel, with the Processing library
# linked in, compiled to JavaScript.
set -eu

cd "$(dirname "$0")"
eval "$(opam env --switch=. --set-switch)"

CMIS=_build/default/lib/.processing.objs/byte
EXPORTS=_build/export.txt

dune build lib/processing.cma toplevel/toplevel.bc

# Units the toplevel must keep around, and whose .cmi it needs in order to
# type-check what people type. Everything the playground can [open].
#
# js_of_ocaml itself is deliberately NOT in this list: embedding its interfaces
# costs 16 MB (Dom_html.cmi alone is 3.4 MB), and Processing already wraps the
# canvas. Add `js_of_ocaml \` below if you want people to reach the raw DOM.
jsoo_listunits -o "$EXPORTS" \
  stdlib \
  js_of_ocaml-compiler.runtime \
  js_of_ocaml-toplevel
echo Processing >>"$EXPORTS"

js_of_ocaml compile \
  --toplevel \
  --export "$EXPORTS" \
  -I "$CMIS" \
  _build/default/toplevel/toplevel.bc \
  -o static/toplevel.js

ls -lh static/toplevel.js | awk '{print $5, $9}'
