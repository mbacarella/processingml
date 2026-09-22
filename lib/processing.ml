(** ProcessingML — a Processing / ProcessingJS ("Khan Academy") style drawing
    library for OCaml, running in the browser on top of js_of_ocaml.

    The whole module is [open]ed by default in the playground, so sketches read
    the way they do in Processing:

    {[
      size ~w:400. ~h:400.;
      background ~r:255 ~g:255 ~b:255;
      fill ~r:255 ~g:0 ~b:0;
      ellipse ~x:200. ~y:200. ~w:120. ~h:120.
    ]}

    Every function that takes more than one value labels them, so there is no
    argument order to remember and no way to transpose [w] and [h] silently.
    Geometry is in [float]s (as in Processing), colour channels are [int]s in
    the 0..255 range. *)

open Js_of_ocaml

let nf = Js.number_of_float
let fn = Js.float_of_number
let js = Js.string

(* ------------------------------------------------------------------ *)
(* Canvas plumbing                                                     *)
(* ------------------------------------------------------------------ *)

let canvas_id = "pml-canvas"
let canvas_ref : Dom_html.canvasElement Js.t option ref = ref None
let ctx_ref : Dom_html.canvasRenderingContext2D Js.t option ref = ref None

let find_canvas () =
  match Dom_html.getElementById_coerce canvas_id Dom_html.CoerceTo.canvas with
  | Some c -> c
  | None ->
      let c = Dom_html.createCanvas Dom_html.document in
      c##.id := js canvas_id;
      Dom.appendChild Dom_html.document##.body c;
      c

let canvas () =
  match !canvas_ref with
  | Some c -> c
  | None ->
      let c = find_canvas () in
      canvas_ref := Some c;
      c

let ctx () =
  match !ctx_ref with
  | Some c -> c
  | None ->
      let c = (canvas ())##getContext Dom_html._2d_ in
      ctx_ref := Some c;
      c

let device_ratio () = fn Dom_html.window##.devicePixelRatio

let perf_now () : float =
  Js.Unsafe.meth_call (Js.Unsafe.get Js.Unsafe.global (js "performance")) "now" [||]

(* ------------------------------------------------------------------ *)
(* Drawing state                                                       *)
(* ------------------------------------------------------------------ *)

type mode = [ `Corner | `Corners | `Center | `Radius ]
type h_align = [ `Left | `Center | `Right ]
type v_align = [ `Top | `Middle | `Baseline | `Bottom ]
type cap = [ `Round | `Square | `Project ]
type join = [ `Miter | `Bevel | `Round ]

type style = {
  mutable fill_c : string option;
  mutable stroke_c : string option;
  mutable weight : float;
  mutable rect_m : mode;
  mutable ell_m : mode;
  mutable t_size : float;
  mutable t_font : string;
  mutable t_h : h_align;
  mutable t_v : v_align;
}

let default_style () =
  {
    fill_c = Some "rgba(255,255,255,1)";
    stroke_c = Some "rgba(0,0,0,1)";
    weight = 1.;
    rect_m = `Corner;
    ell_m = `Center;
    t_size = 12.;
    t_font = "sans-serif";
    t_h = `Left;
    t_v = `Baseline;
  }

let st = ref (default_style ())
let style_stack : style list ref = ref []
let copy_style s = { s with fill_c = s.fill_c }
let width_ = ref 400.
let height_ = ref 400.

let width () = !width_
let height () = !height_

(* Colours ---------------------------------------------------------- *)

let clamp255 v = if v < 0 then 0 else if v > 255 then 255 else v

let rgba ?(a = 255) r g b =
  Printf.sprintf "rgba(%d,%d,%d,%g)" (clamp255 r) (clamp255 g) (clamp255 b)
    (float_of_int (clamp255 a) /. 255.)

(* HSB -> RGB, [h] in 0..360, [s] and [b] in 0..100 (Processing's HSB mode). *)
let rgb_of_hsb h s v =
  let h = Float.rem (Float.rem h 360. +. 360.) 360. in
  let s = Float.max 0. (Float.min 1. (s /. 100.)) in
  let v = Float.max 0. (Float.min 1. (v /. 100.)) in
  let c = v *. s in
  let x = c *. (1. -. Float.abs (Float.rem (h /. 60.) 2. -. 1.)) in
  let m = v -. c in
  let r, g, b =
    if h < 60. then (c, x, 0.)
    else if h < 120. then (x, c, 0.)
    else if h < 180. then (0., c, x)
    else if h < 240. then (0., x, c)
    else if h < 300. then (x, 0., c)
    else (c, 0., x)
  in
  let q f = int_of_float (Float.round ((f +. m) *. 255.)) in
  (q r, q g, q b)

(* ------------------------------------------------------------------ *)
(* Canvas size / reset                                                 *)
(* ------------------------------------------------------------------ *)

let reset_transform () =
  let r = device_ratio () in
  (ctx ())##setTransform (nf r) (nf 0.) (nf 0.) (nf r) (nf 0.) (nf 0.);
  ()

let events_installed = ref false
let install_events : (unit -> unit) ref = ref (fun () -> ())

let size ~w ~h =
  let c = canvas () in
  width_ := w;
  height_ := h;
  let r = device_ratio () in
  c##.width := int_of_float (w *. r);
  c##.height := int_of_float (h *. r);
  c##.style##.width := js (Printf.sprintf "%gpx" w);
  c##.style##.height := js (Printf.sprintf "%gpx" h);
  reset_transform ();
  !install_events ()

(* ------------------------------------------------------------------ *)
(* Style                                                               *)
(* ------------------------------------------------------------------ *)

(* [fill], [stroke] and [background] take several coequal values plus an
   optional alpha, so they end in [()] — that is what lets [?a] be omitted. *)
let fill ?a ~r ~g ~b () = (!st).fill_c <- Some (rgba ?a r g b)
let fill_gray ?a v = fill ?a ~r:v ~g:v ~b:v ()
let fill_hsb ?a ~h ~s ~b () = let r, g, bb = rgb_of_hsb h s b in fill ?a ~r ~g ~b:bb ()
let no_fill () = (!st).fill_c <- None
let stroke ?a ~r ~g ~b () = (!st).stroke_c <- Some (rgba ?a r g b)
let stroke_gray ?a v = stroke ?a ~r:v ~g:v ~b:v ()
let stroke_hsb ?a ~h ~s ~b () = let r, g, bb = rgb_of_hsb h s b in stroke ?a ~r ~g ~b:bb ()
let no_stroke () = (!st).stroke_c <- None
let stroke_weight w = (!st).weight <- w

let stroke_cap (c : cap) =
  (ctx ())##.lineCap :=
    js (match c with `Round -> "round" | `Square -> "butt" | `Project -> "square");
  ()

let stroke_join (j : join) =
  (ctx ())##.lineJoin :=
    js (match j with `Miter -> "miter" | `Bevel -> "bevel" | `Round -> "round");
  ()

let rect_mode (m : mode) = (!st).rect_m <- m
let ellipse_mode (m : mode) = (!st).ell_m <- m

let apply_fill () =
  match (!st).fill_c with
  | None -> false
  | Some c ->
      (ctx ())##.fillStyle := js c;
      true

let apply_stroke () =
  match (!st).stroke_c with
  | None -> false
  | Some c ->
      let cx = ctx () in
      cx##.strokeStyle := js c;
      cx##.lineWidth := nf (!st).weight;
      true

(* A [unit meth] call evaluates to JS [undefined] rather than OCaml's unit
   value, and the toplevel prints that as "<unknown constructor>". Every public
   function below therefore ends on a real [()]. *)
let paint () =
  let cx = ctx () in
  if apply_fill () then cx##fill;
  if apply_stroke () then cx##stroke;
  ()

(* ------------------------------------------------------------------ *)
(* Background / clear                                                  *)
(* ------------------------------------------------------------------ *)

let background ?a ~r ~g ~b () =
  let cx = ctx () in
  cx##save;
  reset_transform ();
  cx##.fillStyle := js (rgba ?a r g b);
  cx##fillRect (nf 0.) (nf 0.) (nf !width_) (nf !height_);
  cx##restore;
  ()

let background_gray ?a v = background ?a ~r:v ~g:v ~b:v ()

let clear () =
  let cx = ctx () in
  cx##save;
  reset_transform ();
  cx##clearRect (nf 0.) (nf 0.) (nf !width_) (nf !height_);
  cx##restore;
  ()

(* ------------------------------------------------------------------ *)
(* Transforms                                                          *)
(* ------------------------------------------------------------------ *)

let push_matrix () =
  (ctx ())##save;
  style_stack := copy_style !st :: !style_stack

let pop_matrix () =
  (ctx ())##restore;
  match !style_stack with
  | [] -> ()
  | s :: tl ->
      st := s;
      style_stack := tl

let translate ~x ~y = (ctx ())##translate (nf x) (nf y); ()
let rotate a = (ctx ())##rotate (nf a); ()

(* [scale 2.] is uniform; pass [~y] as well for a non-uniform scale. *)
let scale ?y x =
  let y = match y with Some y -> y | None -> x in
  (ctx ())##scale (nf x) (nf y);
  ()

let reset_matrix () = reset_transform ()

(* ------------------------------------------------------------------ *)
(* Primitive shapes                                                    *)
(* ------------------------------------------------------------------ *)

(* Normalise (a, b, c, d) to (x, y, w, h) according to [m]. *)
let box (m : mode) a b c d =
  match m with
  | `Corner -> (a, b, c, d)
  | `Corners -> (a, b, c -. a, d -. b)
  | `Center -> (a -. (c /. 2.), b -. (d /. 2.), c, d)
  | `Radius -> (a -. c, b -. d, c *. 2., d *. 2.)

let pi = 4.0 *. atan 1.0
let two_pi = 2. *. pi
let half_pi = pi /. 2.

let point ~x ~y =
  let cx = ctx () in
  match (!st).stroke_c with
  | None -> ()
  | Some c ->
      cx##.fillStyle := js c;
      let w = Float.max 1. (!st).weight in
      cx##beginPath;
      cx##arc (nf x) (nf y) (nf (w /. 2.)) (nf 0.) (nf two_pi) Js._false;
      cx##fill;
      ()

let line ~x1 ~y1 ~x2 ~y2 =
  let cx = ctx () in
  cx##beginPath;
  cx##moveTo (nf x1) (nf y1);
  cx##lineTo (nf x2) (nf y2);
  if apply_stroke () then cx##stroke;
  ()

(* [?r] rounds the corners. *)
let rect ?r ~x ~y ~w ~h () =
  let x, y, w, h = box (!st).rect_m x y w h in
  let cx = ctx () in
  cx##beginPath;
  (match r with
  | Some r when r > 0. ->
      let r = Float.min r (Float.min (Float.abs w /. 2.) (Float.abs h /. 2.)) in
      cx##moveTo (nf (x +. r)) (nf y);
      cx##arcTo (nf (x +. w)) (nf y) (nf (x +. w)) (nf (y +. h)) (nf r);
      cx##arcTo (nf (x +. w)) (nf (y +. h)) (nf x) (nf (y +. h)) (nf r);
      cx##arcTo (nf x) (nf (y +. h)) (nf x) (nf y) (nf r);
      cx##arcTo (nf x) (nf y) (nf (x +. w)) (nf y) (nf r);
      cx##closePath
  | _ -> cx##rect (nf x) (nf y) (nf w) (nf h));
  paint ()

let square ?r ~x ~y ~s () = rect ?r ~x ~y ~w:s ~h:s ()

let ellipse ~x ~y ~w ~h =
  let x, y, w, h = box (!st).ell_m x y w h in
  let cx = ctx () in
  cx##beginPath;
  cx##ellipse (nf (x +. (w /. 2.))) (nf (y +. (h /. 2.)))
    (nf (Float.abs w /. 2.))
    (nf (Float.abs h /. 2.))
    (nf 0.) (nf 0.) (nf two_pi) Js._false;
  paint ()

let circle ~x ~y ~d = ellipse ~x ~y ~w:d ~h:d

let arc ~x ~y ~w ~h ~start ~stop =
  let x, y, w, h = box (!st).ell_m x y w h in
  let cxc = x +. (w /. 2.) and cyc = y +. (h /. 2.) in
  let rx = Float.abs w /. 2. and ry = Float.abs h /. 2. in
  let cx = ctx () in
  (* Filled part is a pie slice, the stroked part is the arc itself. *)
  if (!st).fill_c <> None then begin
    cx##beginPath;
    cx##moveTo (nf cxc) (nf cyc);
    cx##ellipse (nf cxc) (nf cyc) (nf rx) (nf ry) (nf 0.) (nf start) (nf stop)
      Js._false;
    cx##closePath;
    if apply_fill () then cx##fill
  end;
  if (!st).stroke_c <> None then begin
    cx##beginPath;
    cx##ellipse (nf cxc) (nf cyc) (nf rx) (nf ry) (nf 0.) (nf start) (nf stop)
      Js._false;
    if apply_stroke () then cx##stroke
  end

let triangle ~x1 ~y1 ~x2 ~y2 ~x3 ~y3 =
  let cx = ctx () in
  cx##beginPath;
  cx##moveTo (nf x1) (nf y1);
  cx##lineTo (nf x2) (nf y2);
  cx##lineTo (nf x3) (nf y3);
  cx##closePath;
  paint ()

let quad ~x1 ~y1 ~x2 ~y2 ~x3 ~y3 ~x4 ~y4 =
  let cx = ctx () in
  cx##beginPath;
  cx##moveTo (nf x1) (nf y1);
  cx##lineTo (nf x2) (nf y2);
  cx##lineTo (nf x3) (nf y3);
  cx##lineTo (nf x4) (nf y4);
  cx##closePath;
  paint ()

let bezier ~x1 ~y1 ~cx1 ~cy1 ~cx2 ~cy2 ~x2 ~y2 =
  let cx = ctx () in
  cx##beginPath;
  cx##moveTo (nf x1) (nf y1);
  cx##bezierCurveTo (nf cx1) (nf cy1) (nf cx2) (nf cy2) (nf x2) (nf y2);
  if apply_stroke () then cx##stroke;
  ()

(* Free-form shapes -------------------------------------------------- *)

let shape_started = ref false

let begin_shape () =
  let cx = ctx () in
  cx##beginPath;
  shape_started := false

let vertex ~x ~y =
  let cx = ctx () in
  if !shape_started then cx##lineTo (nf x) (nf y)
  else begin
    cx##moveTo (nf x) (nf y);
    shape_started := true
  end;
  ()

let bezier_vertex ~cx1 ~cy1 ~cx2 ~cy2 ~x ~y =
  (ctx ())##bezierCurveTo (nf cx1) (nf cy1) (nf cx2) (nf cy2) (nf x) (nf y);
  ()

let end_shape ?(close = false) () =
  let cx = ctx () in
  if close then cx##closePath;
  paint ()

(* ------------------------------------------------------------------ *)
(* Text                                                                *)
(* ------------------------------------------------------------------ *)

let apply_font () =
  (ctx ())##.font := js (Printf.sprintf "%gpx %s" (!st).t_size (!st).t_font);
  ()

let text_size s =
  (!st).t_size <- s;
  apply_font ()

let text_font f =
  (!st).t_font <- f;
  apply_font ()

let text_align ?(v : v_align = `Baseline) (h : h_align) =
  (!st).t_h <- h;
  (!st).t_v <- v

(* [?size] and [?align] apply to this call only. *)
let text ?size ?align ~x ~y str =
  let saved_size = (!st).t_size and saved_align = (!st).t_h in
  (match size with Some s -> (!st).t_size <- s | None -> ());
  (match align with Some a -> (!st).t_h <- a | None -> ());
  let cx = ctx () in
  apply_font ();
  cx##.textAlign :=
    js (match (!st).t_h with `Left -> "left" | `Center -> "center" | `Right -> "right");
  cx##.textBaseline :=
    js
      (match (!st).t_v with
      | `Top -> "top"
      | `Middle -> "middle"
      | `Baseline -> "alphabetic"
      | `Bottom -> "bottom");
  if apply_fill () then cx##fillText (js str) (nf x) (nf y);
  if apply_stroke () && (!st).weight > 0. && (!st).fill_c = None then
    cx##strokeText (js str) (nf x) (nf y);
  (!st).t_size <- saved_size;
  (!st).t_h <- saved_align

let text_width str =
  apply_font ();
  fn ((ctx ())##measureText (js str))##.width

(* ------------------------------------------------------------------ *)
(* Maths helpers                                                       *)
(* ------------------------------------------------------------------ *)

(* The value being transformed stays positional, and comes last. *)
let random ?(min = 0.) max = min +. Random.float (max -. min)
let random_int ?(min = 0) max = if max <= min then min else min + Random.int (max - min)
let random_seed s = Random.init s
let dist ~x1 ~y1 ~x2 ~y2 = sqrt (((x2 -. x1) ** 2.) +. ((y2 -. y1) ** 2.))
let mag ~x ~y = sqrt ((x *. x) +. (y *. y))
let lerp ~a ~b ~t = a +. ((b -. a) *. t)
let norm ~lo ~hi v = if hi = lo then 0. else (v -. lo) /. (hi -. lo)

(* [map_range ~src:(0., 1.) ~dst:(0., 400.) v] *)
let map_range ~src:(lo1, hi1) ~dst:(lo2, hi2) v =
  if hi1 = lo1 then lo2 else lo2 +. ((v -. lo1) /. (hi1 -. lo1) *. (hi2 -. lo2))

let constrain ~lo ~hi v = if v < lo then lo else if v > hi then hi else v
let radians d = d *. pi /. 180.
let degrees r = r *. 180. /. pi
let sq x = x *. x

(* Improved Perlin noise (Ken Perlin, 2002). *)
let perm = Array.make 512 0

let noise_seed seed =
  let state = Random.State.make [| seed |] in
  let p = Array.init 256 (fun i -> i) in
  for i = 255 downto 1 do
    let j = Random.State.int state (i + 1) in
    let t = p.(i) in
    p.(i) <- p.(j);
    p.(j) <- t
  done;
  for i = 0 to 511 do
    perm.(i) <- p.(i land 255)
  done

let () = noise_seed 0

let fade t = t *. t *. t *. ((t *. ((t *. 6.) -. 15.)) +. 10.)

let grad hash x y z =
  let h = hash land 15 in
  let u = if h < 8 then x else y in
  let v = if h < 4 then y else if h = 12 || h = 14 then x else z in
  (if h land 1 = 0 then u else -.u) +. if h land 2 = 0 then v else -.v

let noise ?(y = 0.) ?(z = 0.) x =
  let fx = Float.of_int (int_of_float (Float.floor x)) in
  let fy = Float.of_int (int_of_float (Float.floor y)) in
  let fz = Float.of_int (int_of_float (Float.floor z)) in
  let xi = int_of_float fx land 255
  and yi = int_of_float fy land 255
  and zi = int_of_float fz land 255 in
  let x = x -. fx and y = y -. fy and z = z -. fz in
  let u = fade x and v = fade y and w = fade z in
  let a = perm.(xi) + yi in
  let aa = perm.(a land 255) + zi and ab = perm.((a + 1) land 255) + zi in
  let b = perm.((xi + 1) land 255) + yi in
  let ba = perm.(b land 255) + zi and bb = perm.((b + 1) land 255) + zi in
  let l a b t = lerp ~a ~b ~t in
  let res =
    l
      (l
         (l (grad perm.(aa land 255) x y z) (grad perm.(ba land 255) (x -. 1.) y z) u)
         (l
            (grad perm.(ab land 255) x (y -. 1.) z)
            (grad perm.(bb land 255) (x -. 1.) (y -. 1.) z)
            u)
         v)
      (l
         (l
            (grad perm.((aa + 1) land 255) x y (z -. 1.))
            (grad perm.((ba + 1) land 255) (x -. 1.) y (z -. 1.))
            u)
         (l
            (grad perm.((ab + 1) land 255) x (y -. 1.) (z -. 1.))
            (grad perm.((bb + 1) land 255) (x -. 1.) (y -. 1.) (z -. 1.))
            u)
         v)
      w
  in
  (res +. 1.) /. 2.

(* ------------------------------------------------------------------ *)
(* Mouse / keyboard state                                              *)
(* ------------------------------------------------------------------ *)

let mouse_x_ = ref 0.
let mouse_y_ = ref 0.
let pmouse_x_ = ref 0.
let pmouse_y_ = ref 0.
let mouse_down = ref false
let key_down = ref false
let key_str = ref ""
let key_code_ = ref 0

let mouse_x () = !mouse_x_
let mouse_y () = !mouse_y_
let pmouse_x () = !pmouse_x_
let pmouse_y () = !pmouse_y_
let mouse_is_pressed () = !mouse_down
let key_is_pressed () = !key_down
let key_char () = !key_str
let key_code () = !key_code_

type handlers = {
  mutable on_draw : (unit -> unit) option;
  mutable on_mouse_pressed : (unit -> unit) option;
  mutable on_mouse_released : (unit -> unit) option;
  mutable on_mouse_moved : (unit -> unit) option;
  mutable on_mouse_dragged : (unit -> unit) option;
  mutable on_mouse_clicked : (unit -> unit) option;
  mutable on_key_pressed : (unit -> unit) option;
  mutable on_key_released : (unit -> unit) option;
}

let hs =
  {
    on_draw = None;
    on_mouse_pressed = None;
    on_mouse_released = None;
    on_mouse_moved = None;
    on_mouse_dragged = None;
    on_mouse_clicked = None;
    on_key_pressed = None;
    on_key_released = None;
  }

(* Errors raised by user callbacks are reported on stderr (which the playground
   routes to its console pane) and stop the sketch rather than flooding it. *)
let report_error where e =
  prerr_endline
    (Printf.sprintf "Runtime error in %s: %s" where (Printexc.to_string e));
  flush stderr

let safe where f =
  try
    f ();
    flush stdout;
    flush stderr;
    true
  with e ->
    report_error where e;
    false

let run_handler name = function
  | None -> ()
  | Some f -> ignore (safe name f : bool)

(* ------------------------------------------------------------------ *)
(* The draw loop                                                       *)
(* ------------------------------------------------------------------ *)

let looping = ref true
let frame_count_ = ref 0
let target_fps = ref 60.
let last_frame = ref neg_infinity
let raf_pending = ref false
let start_time = ref 0.

let frame_count () = !frame_count_
let millis () = perf_now () -. !start_time

let rec on_frame (_t : Js.number_t) =
  raf_pending := false;
  match hs.on_draw with
  | None -> ()
  | Some f ->
      if !looping then begin
        let now = perf_now () in
        let interval = 1000. /. !target_fps in
        if now -. !last_frame >= interval -. 1. then begin
          last_frame := now;
          incr frame_count_;
          let ok = safe "draw" f in
          pmouse_x_ := !mouse_x_;
          pmouse_y_ := !mouse_y_;
          if not ok then hs.on_draw <- None
        end;
        match hs.on_draw with Some _ -> request_frame () | None -> ()
      end

and request_frame () =
  if not !raf_pending then begin
    raf_pending := true;
    ignore
      (Dom_html.window##requestAnimationFrame (Js.wrap_callback on_frame)
        : Dom_html.animation_frame_request_id)
  end

let draw ?fps f =
  (match fps with Some v -> target_fps := Float.max 1. v | None -> ());
  hs.on_draw <- Some f;
  if !start_time = 0. then start_time := perf_now ();
  looping := true;
  request_frame ()

let no_loop () = looping := false

let loop () =
  looping := true;
  request_frame ()

let frame_rate fps = target_fps := Float.max 1. fps
let mouse_pressed f = hs.on_mouse_pressed <- Some f
let mouse_released f = hs.on_mouse_released <- Some f
let mouse_moved f = hs.on_mouse_moved <- Some f
let mouse_dragged f = hs.on_mouse_dragged <- Some f
let mouse_clicked f = hs.on_mouse_clicked <- Some f
let key_pressed f = hs.on_key_pressed <- Some f
let key_released f = hs.on_key_released <- Some f

(* ------------------------------------------------------------------ *)
(* DOM event wiring                                                    *)
(* ------------------------------------------------------------------ *)

let update_mouse (ev : Dom_html.mouseEvent Js.t) =
  let c = canvas () in
  let r = c##getBoundingClientRect in
  pmouse_x_ := !mouse_x_;
  pmouse_y_ := !mouse_y_;
  mouse_x_ := fn ev##.clientX -. fn r##.left;
  mouse_y_ := fn ev##.clientY -. fn r##.top

let do_install_events () =
  if not !events_installed then begin
    events_installed := true;
    let c = canvas () in
    let listen el ev h = ignore (Dom_html.addEventListener el ev (Dom_html.handler h) Js._false) in
    listen c Dom_html.Event.mousemove (fun ev ->
        update_mouse ev;
        run_handler "mouse_moved" hs.on_mouse_moved;
        if !mouse_down then run_handler "mouse_dragged" hs.on_mouse_dragged;
        Js._true);
    listen c Dom_html.Event.mousedown (fun ev ->
        update_mouse ev;
        mouse_down := true;
        run_handler "mouse_pressed" hs.on_mouse_pressed;
        Js._true);
    listen Dom_html.window Dom_html.Event.mouseup (fun ev ->
        update_mouse ev;
        mouse_down := false;
        run_handler "mouse_released" hs.on_mouse_released;
        Js._true);
    listen c Dom_html.Event.click (fun ev ->
        update_mouse ev;
        run_handler "mouse_clicked" hs.on_mouse_clicked;
        Js._true);
    listen Dom_html.document Dom_html.Event.keydown (fun ev ->
        key_down := true;
        key_code_ := ev##.keyCode;
        key_str := Js.to_string (Js.Optdef.get ev##.key (fun () -> js ""));
        run_handler "key_pressed" hs.on_key_pressed;
        Js._true);
    listen Dom_html.document Dom_html.Event.keyup (fun ev ->
        key_down := false;
        key_code_ := ev##.keyCode;
        key_str := Js.to_string (Js.Optdef.get ev##.key (fun () -> js ""));
        run_handler "key_released" hs.on_key_released;
        Js._true)
  end

let () = install_events := do_install_events

(* ------------------------------------------------------------------ *)
(* Sketch lifecycle                                                    *)
(* ------------------------------------------------------------------ *)

(** [reset ()] tears down the running sketch: it stops the draw loop, forgets
    every event handler, restores the default style and clears the canvas. The
    playground calls it before each run. *)
let reset () =
  hs.on_draw <- None;
  hs.on_mouse_pressed <- None;
  hs.on_mouse_released <- None;
  hs.on_mouse_moved <- None;
  hs.on_mouse_dragged <- None;
  hs.on_mouse_clicked <- None;
  hs.on_key_pressed <- None;
  hs.on_key_released <- None;
  looping := true;
  frame_count_ := 0;
  last_frame := neg_infinity;
  target_fps := 60.;
  start_time := perf_now ();
  style_stack := [];
  st := default_style ();
  let cx = ctx () in
  (* Drop any transform/clip left behind by an unbalanced push_matrix. *)
  (try
     for _ = 1 to 32 do
       cx##restore
     done
   with _ -> ());
  size ~w:400. ~h:400.;
  background ~r:255 ~g:255 ~b:255 ();
  shape_started := false
