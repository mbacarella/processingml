// Sketches offered in the Examples dropdown. The first one is what a fresh
// visitor sees.
window.EXAMPLES = [
  {
    name: "Shapes",
    code: `(* ProcessingML — the OCaml toplevel, with a canvas attached.
   Press Run, or hit Ctrl/Cmd + Enter.

   Geometry is float, colour channels are int 0..255. *)

let () =
  size 400. 400.;
  background 252 250 245;

  no_stroke ();
  fill 244 114 94;
  ellipse 150. 150. 180. 180.;

  fill ~a:190 80 140 220;
  rect 170. 170. 170. 170.;

  no_fill ();
  stroke 40 40 40;
  stroke_weight 3.;
  triangle 60. 350. 200. 240. 340. 350.;

  no_stroke ();
  fill 40 40 40;
  text_size 15.;
  text "ellipse, rect, triangle" 20. 32.
`,
  },

  {
    name: "Camel",
    code: `(* A camel, in the ocaml.org palette. *)

let sand  = (250, 248, 243)   (* #faf8f3 *)
let dune  = (231, 181, 115)   (* #e7b573 *)
let coat  = (225, 140, 52)    (* #e18c34 *)
let shade = (194, 79, 30)     (* #c24f1e *)
let sun   = (213, 64, 0)      (* #d54000 *)
let ink   = (17, 24, 39)      (* #111827 *)

let fill_c ?a (r, g, b) = fill ?a r g b
let stroke_c ?a (r, g, b) = stroke ?a r g b

let leg ?(w = 15.) colour (hip_x, hip_y) (knee_x, knee_y) (foot_x, foot_y) =
  stroke_c colour;
  stroke_weight w;
  line hip_x hip_y knee_x knee_y;
  line knee_x knee_y foot_x foot_y;
  no_stroke ();
  fill_c colour;
  ellipse foot_x (foot_y +. 2.) (w +. 6.) 9.

let () =
  size 400. 400.;
  let r, g, b = sand in
  background r g b;
  no_stroke ();
  stroke_cap \`Round;

  (* sun, then the dunes it sits behind *)
  fill_c ~a:36 sun;
  ellipse 92. 92. 140. 140.;
  fill_c sun;
  ellipse 92. 92. 76. 76.;
  fill_c ~a:90 dune;
  ellipse 52. 392. 280. 96.;
  ellipse 358. 386. 240. 84.;
  fill_c ~a:130 dune;
  ellipse 200. 480. 660. 260.;
  fill_c ~a:55 shade;
  ellipse 208. 354. 250. 22.;

  (* tail, before the body so it comes out from behind the rump *)
  no_fill ();
  stroke_c shade;
  stroke_weight 5.;
  bezier 118. 226. 92. 248. 102. 272. 86. 290.;
  no_stroke ();
  fill_c ink;
  ellipse 84. 296. 13. 17.;

  (* the far pair of legs is darker, so the animal has some depth *)
  leg ~w:12. shade (152., 252.) (142., 302.) (152., 348.);
  leg ~w:12. shade (244., 250.) (254., 302.) (244., 348.);

  (* one closed outline for rump, hump, shoulder and belly *)
  fill_c coat;
  begin_shape ();
  vertex 112. 238.;
  bezier_vertex 112. 216. 128. 202. 162. 202.;
  bezier_vertex 176. 130. 228. 132. 248. 202.;
  bezier_vertex 262. 208. 282. 212. 296. 226.;
  bezier_vertex 302. 260. 274. 284. 236. 288.;
  bezier_vertex 186. 296. 126. 290. 112. 238.;
  end_shape ~close:true ();

  (* neck *)
  begin_shape ();
  vertex 240. 242.;
  vertex 292. 216.;
  vertex 340. 118.;
  vertex 304. 104.;
  end_shape ~close:true ();

  (* head, drawn in its own rotated frame *)
  push_matrix ();
  translate 326. 104.;
  rotate (radians (-16.));
  fill_c coat;
  ellipse 0. 0. 76. 48.;
  ellipse 34. 12. 42. 30.;
  fill_c shade;
  triangle (-22.) (-14.) (-34.) (-40.) (-8.) (-24.);
  fill_c ink;
  ellipse 10. (-9.) 8. 8.;
  ellipse 50. 10. 5. 5.;
  pop_matrix ();

  (* the near pair of legs, and a little belly shading *)
  fill_c ~a:35 shade;
  ellipse 200. 274. 150. 26.;
  leg coat (178., 256.) (188., 304.) (178., 350.);
  leg coat (270., 252.) (262., 304.) (272., 350.)
`,
  },

  {
    name: "Bouncing ball",
    code: `(* A draw loop: the function you hand to [draw] runs every frame. *)

let x = ref 200. and y = ref 120.
let vx = ref 3.2 and vy = ref 2.3
let r = 26.

let () =
  size 400. 400.;
  draw (fun () ->
      background 24 26 33;

      x := !x +. !vx;
      y := !y +. !vy;
      if !x < r || !x > width () -. r then vx := -. !vx;
      if !y < r || !y > height () -. r then vy := -. !vy;

      no_stroke ();
      fill 255 209 102;
      ellipse !x !y (r *. 2.) (r *. 2.);

      fill 130 136 150;
      text_size 12.;
      text (Printf.sprintf "frame %d" (frame_count ())) 12. 22.)
`,
  },

  {
    name: "Mouse trail",
    code: `(* Move the mouse over the canvas. *)

let () =
  size 400. 400.;
  background 250 250 252;
  no_stroke ();
  draw (fun () ->
      let speed = dist (mouse_x ()) (mouse_y ()) (pmouse_x ()) (pmouse_y ()) in
      let d = constrain (speed *. 1.6) 5. 46. in
      let hue = Float.rem (float_of_int (frame_count ()) *. 2.5) 360. in
      fill_hsb ~a:190 hue 65. 95.;
      ellipse (mouse_x ()) (mouse_y ()) d d)

let () =
  mouse_pressed (fun () -> background 250 250 252)
`,
  },

  {
    name: "Recursive tree",
    code: `(* Recursion plus push_matrix / pop_matrix. *)

let rec branch len depth =
  if depth > 0 then begin
    stroke_weight (float_of_int depth *. 0.7);
    line 0. 0. 0. (-. len);

    push_matrix ();
    translate 0. (-. len);
    rotate (radians 24.);
    branch (len *. 0.74) (depth - 1);
    pop_matrix ();

    push_matrix ();
    translate 0. (-. len);
    rotate (radians (-22.));
    branch (len *. 0.68) (depth - 1);
    pop_matrix ()
  end

let () =
  size 400. 400.;
  background 250 248 240;
  stroke 74 56 44;
  push_matrix ();
  translate 200. 390.;
  branch 92. 10;
  pop_matrix ()
`,
  },

  {
    name: "Perlin flow",
    code: `(* Perlin noise, sampled through time. *)

let () =
  size 400. 400.;
  background 16 17 22;
  no_stroke ();
  draw (fun () ->
      let t = float_of_int (frame_count ()) *. 0.006 in
      (* Fade the previous frame instead of clearing it. *)
      fill ~a:18 16 17 22;
      rect 0. 0. (width ()) (height ());

      for i = 0 to 300 do
        let a = float_of_int i in
        let x = map_range (noise ~y:t (a *. 0.06)) 0. 1. 0. (width ()) in
        let y = map_range (noise ~y:(t +. 40.) (a *. 0.06 +. 90.)) 0. 1. 0. (height ()) in
        let hue = map_range (noise ~y:t (a *. 0.01)) 0. 1. 170. 330. in
        fill_hsb ~a:170 hue 70. 100.;
        ellipse x y 3.5 3.5
      done)
`,
  },

  {
    name: "Rainbow spiral",
    code: `let () =
  size 400. 400.;
  background 255 255 255;
  no_stroke ();
  for i = 0 to 520 do
    let a = float_of_int i in
    let r = a *. 0.34 in
    let x = 200. +. (r *. cos (a *. 0.22)) in
    let y = 200. +. (r *. sin (a *. 0.22)) in
    fill_hsb (Float.rem (a *. 1.4) 360.) 78. 96.;
    ellipse x y (3. +. (r *. 0.06)) (3. +. (r *. 0.06))
  done
`,
  },

  {
    name: "Game of life",
    code: `(* Arrays, pattern matching and a 12 fps draw loop.
   Click the canvas to reseed. *)

let cols = 40
let rows = 40
let cell = 10.

let fresh () =
  Array.init cols (fun _ -> Array.init rows (fun _ -> Random.int 2))

let neighbours g x y =
  let n = ref 0 in
  for dx = -1 to 1 do
    for dy = -1 to 1 do
      if dx <> 0 || dy <> 0 then begin
        let nx = (x + dx + cols) mod cols and ny = (y + dy + rows) mod rows in
        n := !n + g.(nx).(ny)
      end
    done
  done;
  !n

let step g =
  Array.init cols (fun x ->
      Array.init rows (fun y ->
          match g.(x).(y), neighbours g x y with
          | 1, (2 | 3) -> 1
          | 0, 3 -> 1
          | _ -> 0))

let world = ref (fresh ())

let () =
  size 400. 400.;
  frame_rate 12.;
  mouse_pressed (fun () -> world := fresh ());
  draw (fun () ->
      background 15 17 21;
      no_stroke ();
      fill 126 231 135;
      Array.iteri
        (fun x col ->
          Array.iteri
            (fun y v ->
              if v = 1 then
                rect
                  (float_of_int x *. cell)
                  (float_of_int y *. cell)
                  (cell -. 1.) (cell -. 1.))
            col)
        !world;
      world := step !world)
`,
  },

  {
    name: "Typing it out",
    code: `(* The toplevel is a real toplevel: values are printed back to the
   console, and definitions survive between runs. *)

let fib = Seq.unfold (fun (a, b) -> Some (a, (b, a + b))) (0, 1)
let first_15 = List.of_seq (Seq.take 15 fib)

let () = List.iteri (Printf.printf "fib %2d = %d\\n") first_15

let () =
  size 400. 400.;
  background 255 255 255;
  fill 30 30 40;
  text_size 13.;
  List.iteri
    (fun i n ->
      let y = 30. +. (float_of_int i *. 24.) in
      text (Printf.sprintf "%2d" n) 20. y;
      no_stroke ();
      fill ~a:140 90 150 230;
      rect 60. (y -. 11.) (float_of_int n *. 0.6) 14.;
      fill 30 30 40)
    first_15
`,
  },
];
