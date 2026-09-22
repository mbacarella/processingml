# ProcessingML

An in-browser OCaml playground in the spirit of [ocaml.org/play](https://ocaml.org/play),
with two additions:

* a **canvas** next to the editor, and
* a **Processing / ProcessingJS-style drawing library** opened by default —
  `ellipse`, `fill`, `draw`, `mouse_x`, `noise`, … the vocabulary you get in the
  Khan Academy ProcessingJS environment, spelled the OCaml way.

Everything runs client-side: a real OCaml toplevel compiled to JavaScript with
js_of_ocaml, so the type errors, the inferred types and the printed values are
the genuine article.

```ocaml
let () =
  size ~w:400. ~h:400.;
  background ~r:252 ~g:250 ~b:245 ();
  no_stroke ();
  fill ~r:244 ~g:114 ~b:94 ();
  ellipse ~x:150. ~y:150. ~w:180. ~h:180.
```

## Quick start

```sh
./build.sh                     # compiles everything into static/
xdg-open static/index.html     # …and that is enough
```

`build.sh` uses the project-local opam switch in `./_opam` (created with
`opam switch create . 4.14.2`), so it will not touch your global switches.

**The output is a plain static site.** `static/` after a build is
self-contained — `index.html`, three small scripts, a stylesheet and
`toplevel.js` — and it runs from `file://` or from any static host. There is no
server-side anything: the compiler is in the JavaScript. If you want it on
localhost over HTTP, `make serve` is just
`python3 -m http.server -d static 8000`.

`toplevel.js` is ~4.9 MB raw and ~1.0 MB gzipped, so serve it with compression
enabled; GitHub Pages, S3+CloudFront and nginx (`gzip_types application/javascript`)
all do that for you.

## Using it

| | |
|---|---|
| **Run** | `Ctrl`/`Cmd` + `Enter`, or the Run button. Resets the canvas, then evaluates the whole editor buffer. |
| **Stop** | Pauses the draw loop without clearing the canvas. |
| **Reset** | Stops the sketch, restores default style, clears the canvas. |
| **`#` prompt** | Under the console: evaluates in the *same* toplevel session without resetting, so you can inspect or poke a running sketch (`frame_count ()`, `vx := 12.`). |
| **Copy link** | Puts the sketch in the URL fragment. |
| **Reference** | The full library API. |

The toplevel session persists between runs — only the canvas is reset — so
definitions from an earlier run stay in scope, exactly like a toplevel.

## The drawing library

`lib/processing.ml`, with the full signature in `lib/processing.mli`.
Conventions:

* geometry is `float` (as in Processing), colour channels are `int` in `0..255`
* angles are radians; `radians`/`degrees` convert
* Processing's overloads become separate names: `fill` / `fill_gray` / `fill_hsb`
* enum-ish arguments are polymorphic variants: ``rect_mode `Center``

**Every value argument is labelled**, so there is no argument order to remember
and no way to transpose `~w` and `~h` silently. Two consequences:

* Where one value is clearly the subject it stays *positional, and last*:
  `text ~x:20. ~y:30. "hi"`, `noise ~y:t 0.5`, `draw (fun () -> ...)`.
* A function taking several coequal values *and* an optional one ends in `()`:
  `fill ~r:255 ~g:0 ~b:0 ()`. OCaml only drops an optional argument when a
  positional one follows it, so that `()` is what makes `?a` omissible. Forget
  it and you get a type error, not a silent no-op:

  ```
  # fill ~r:255 ~g:0 ~b:0;;
  Error: This expression has type ?a:int -> unit -> unit
         but an expression was expected of type unit
  ```

  The seven such functions are `fill`, `stroke`, `background`, `fill_hsb`,
  `stroke_hsb`, `rect` and `square`.

Labels may be given in any order, and a fully-applied call may still omit them
entirely (with a `labels-omitted` warning), so pasted Processing code mostly
still works.

```ocaml
(* a draw loop *)
let x = ref 200.

let () =
  size ~w:400. ~h:400.;
  draw ~fps:30. (fun () ->
      background ~r:24 ~g:26 ~b:33 ();
      x := !x +. 2.;
      if !x > width () then x := 0.;
      fill ~r:255 ~g:209 ~b:102 ();
      no_stroke ();
      ellipse ~x:!x ~y:200. ~w:40. ~h:40.)
```

Errors raised inside `draw` (or any event callback) are printed to the console
and stop the sketch rather than repeating sixty times a second.

To add a function, edit `lib/processing.ml` and re-run `./build.sh`; the
toplevel picks it up because the library is linked into it and its `.cmi` is
embedded in the toplevel's virtual filesystem.

## How it fits together

```
lib/processing.ml      the drawing library (js_of_ocaml canvas bindings)
toplevel/toplevel.ml   JsooTop driver; exposes window.OCamlTop to the page
build.sh               dune → toplevel.bc → js_of_ocaml --toplevel → toplevel.js
static/                index.html, style.css, app.js, examples.js (+ toplevel.js)
```

`build.sh` lists the units to export with `jsoo_listunits` (stdlib, the
js_of_ocaml runtime, the toplevel, and `Processing`) and passes `-I` at the
`.processing.objs` directory so js_of_ocaml embeds `processing.cmi` under
`/static/cmis` — that is what lets the in-browser type-checker resolve
`Processing`.

### Why toplevel.js is the size it is

`--toplevel` embeds the `.cmi` of every exported unit, because the in-browser
type-checker needs the interfaces. Those interfaces dominate the output, so the
export list is the size knob:

| exported | `toplevel.js` |
|---|---|
| stdlib + runtime + toplevel + `Processing` | 4.9 MB (1.0 MB gzipped) |
| …plus the `js_of_ocaml` bindings | 21 MB |

`Dom_html.cmi` alone is 3.4 MB on disk and inflates roughly fourfold once
embedded as a JavaScript string. `Processing` already wraps the canvas, so the
bindings are left out; add `js_of_ocaml` back to the `jsoo_listunits` call in
`build.sh` if you want people to reach the raw DOM. `lib/processing.mli` keeps
the library's own interface free of `Js.t` types, which is what makes that
omission safe.

The page talks to the toplevel through a small JS API:

```js
OCamlTop.init()              // start it; returns the OCaml version
OCamlTop.setSink(fn)         // fn(kind, text), kind = "result" | "out" | "err"
OCamlTop.exec(code, reset)   // evaluate, optionally resetting the sketch first
OCamlTop.reset()             // tear the sketch down
OCamlTop.noLoop() / loop()
```

Output is streamed through the sink rather than returned, so `print_endline`
from inside a draw loop shows up in the console as it happens.

## Deploying

`.github/workflows/pages.yml` builds the project on GitHub Actions and publishes
`static/` to GitHub Pages, so the generated `toplevel.js` never enters the repo —
it is rebuilt on each push to `main`. Enable it once under
*Settings → Pages → Source → GitHub Actions*.

Pages gzips JavaScript on the way out, so the visitor downloads ~1 MB.

## Known limitations

* OCaml 4.14.2 only — no version picker like ocaml.org/play. Adding one means
  building one `toplevel.js` per switch and choosing at load time.
* Sketches run on the main thread, so an infinite loop in your code freezes the
  tab (ocaml.org/play sidesteps this with a web worker, which is not an option
  here without moving the canvas to an `OffscreenCanvas`).
* `#use`, `#require` and dynlink of external libraries are not wired up.
* The editor uses CodeMirror from a CDN and quietly falls back to a plain
  textarea when that is unavailable — which is what you get if you open the
  page from `file://` with no network. Vendoring CodeMirror into `static/`
  would make the whole thing offline-complete.
