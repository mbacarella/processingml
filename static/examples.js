// Sketches offered in the Examples dropdown. The first one is what a fresh
// visitor sees.
window.EXAMPLES = [
  {
    name: "Shapes",
    code: `(* ProcessingML — the OCaml toplevel, with a canvas attached.
   Press Run, or hit Ctrl/Cmd + Enter.

   Every value is labelled, so there is no argument order to remember and
   no way to transpose ~w and ~h by accident. A call ending in () is one
   that takes an optional argument — here ~a (alpha) and ~r (corner radius).
   Geometry is float, colour channels are int 0..255. *)

let () =
  size ~w:400. ~h:400.;
  background ~r:252 ~g:250 ~b:245 ();

  no_stroke ();
  fill ~r:244 ~g:114 ~b:94 ();
  ellipse ~x:150. ~y:150. ~w:180. ~h:180.;

  fill ~a:190 ~r:80 ~g:140 ~b:220 ();
  rect ~r:14. ~x:170. ~y:170. ~w:170. ~h:170. ();

  no_fill ();
  stroke ~r:40 ~g:40 ~b:40 ();
  stroke_weight 3.;
  triangle ~x1:60. ~y1:350. ~x2:200. ~y2:240. ~x3:340. ~y3:350.;

  no_stroke ();
  fill ~r:40 ~g:40 ~b:40 ();
  text ~size:15. ~x:20. ~y:32. "ellipse, rect, triangle"
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

(* The colour stays positional and last, so ?a still erases: both
   [fill_c coat] and [fill_c ~a:90 dune] type-check. *)
let fill_c ?a (r, g, b) = fill ?a ~r ~g ~b ()
let stroke_c ?a (r, g, b) = stroke ?a ~r ~g ~b ()

let leg ?(w = 15.) ~hip:(hx, hy) ~knee:(kx, ky) ~foot:(fx, fy) colour =
  stroke_c colour;
  stroke_weight w;
  line ~x1:hx ~y1:hy ~x2:kx ~y2:ky;
  line ~x1:kx ~y1:ky ~x2:fx ~y2:fy;
  no_stroke ();
  fill_c colour;
  ellipse ~x:fx ~y:(fy +. 2.) ~w:(w +. 6.) ~h:9.

let () =
  size ~w:400. ~h:400.;
  let r, g, b = sand in
  background ~r ~g ~b ();
  no_stroke ();
  stroke_cap \`Round;

  (* sun, then the dunes it sits behind *)
  fill_c ~a:36 sun;
  ellipse ~x:92. ~y:92. ~w:140. ~h:140.;
  fill_c sun;
  ellipse ~x:92. ~y:92. ~w:76. ~h:76.;
  fill_c ~a:90 dune;
  ellipse ~x:52. ~y:392. ~w:280. ~h:96.;
  ellipse ~x:358. ~y:386. ~w:240. ~h:84.;
  fill_c ~a:130 dune;
  ellipse ~x:200. ~y:480. ~w:660. ~h:260.;
  fill_c ~a:55 shade;
  ellipse ~x:208. ~y:354. ~w:250. ~h:22.;

  (* tail, before the body so it comes out from behind the rump *)
  no_fill ();
  stroke_c shade;
  stroke_weight 5.;
  bezier ~x1:118. ~y1:226. ~cx1:92. ~cy1:248.
         ~cx2:102. ~cy2:272. ~x2:86. ~y2:290.;
  no_stroke ();
  fill_c ink;
  ellipse ~x:84. ~y:296. ~w:13. ~h:17.;

  (* the far pair of legs is darker, so the animal has some depth *)
  leg ~w:12. ~hip:(152., 252.) ~knee:(142., 302.) ~foot:(152., 348.) shade;
  leg ~w:12. ~hip:(244., 250.) ~knee:(254., 302.) ~foot:(244., 348.) shade;

  (* one closed outline for rump, hump, shoulder and belly *)
  fill_c coat;
  begin_shape ();
  vertex ~x:112. ~y:238.;
  bezier_vertex ~cx1:112. ~cy1:216. ~cx2:128. ~cy2:202. ~x:162. ~y:202.;
  bezier_vertex ~cx1:176. ~cy1:130. ~cx2:228. ~cy2:132. ~x:248. ~y:202.;
  bezier_vertex ~cx1:262. ~cy1:208. ~cx2:282. ~cy2:212. ~x:296. ~y:226.;
  bezier_vertex ~cx1:302. ~cy1:260. ~cx2:274. ~cy2:284. ~x:236. ~y:288.;
  bezier_vertex ~cx1:186. ~cy1:296. ~cx2:126. ~cy2:290. ~x:112. ~y:238.;
  end_shape ~close:true ();

  (* neck *)
  begin_shape ();
  vertex ~x:240. ~y:242.;
  vertex ~x:292. ~y:216.;
  vertex ~x:340. ~y:118.;
  vertex ~x:304. ~y:104.;
  end_shape ~close:true ();

  (* head, drawn in its own rotated frame *)
  push_matrix ();
  translate ~x:326. ~y:104.;
  rotate (radians (-16.));
  fill_c coat;
  ellipse ~x:0. ~y:0. ~w:76. ~h:48.;
  ellipse ~x:34. ~y:12. ~w:42. ~h:30.;
  fill_c shade;
  triangle ~x1:(-22.) ~y1:(-14.) ~x2:(-34.) ~y2:(-40.) ~x3:(-8.) ~y3:(-24.);
  fill_c ink;
  ellipse ~x:10. ~y:(-9.) ~w:8. ~h:8.;
  ellipse ~x:50. ~y:10. ~w:5. ~h:5.;
  pop_matrix ();

  (* the near pair of legs, and a little belly shading *)
  fill_c ~a:35 shade;
  ellipse ~x:200. ~y:274. ~w:150. ~h:26.;
  leg ~hip:(178., 256.) ~knee:(188., 304.) ~foot:(178., 350.) coat;
  leg ~hip:(270., 252.) ~knee:(262., 304.) ~foot:(272., 350.) coat
`,
  },

  {
    name: "Bouncing ball",
    code: `(* A draw loop: the function you hand to [draw] runs every frame.
   [draw] keeps its callback positional and last, so ?fps still erases. *)

let x = ref 200. and y = ref 120.
let vx = ref 3.2 and vy = ref 2.3
let r = 26.

let () =
  size ~w:400. ~h:400.;
  draw (fun () ->
      background ~r:24 ~g:26 ~b:33 ();

      x := !x +. !vx;
      y := !y +. !vy;
      if !x < r || !x > width () -. r then vx := -. !vx;
      if !y < r || !y > height () -. r then vy := -. !vy;

      no_stroke ();
      fill ~r:255 ~g:209 ~b:102 ();
      ellipse ~x:!x ~y:!y ~w:(r *. 2.) ~h:(r *. 2.);

      fill ~r:130 ~g:136 ~b:150 ();
      text ~size:12. ~x:12. ~y:22.
        (Printf.sprintf "frame %d" (frame_count ())))
`,
  },

  {
    name: "Mouse trail",
    code: `(* Move the mouse over the canvas; click to wipe it. *)

let () =
  size ~w:400. ~h:400.;
  background ~r:250 ~g:250 ~b:252 ();
  no_stroke ();
  draw (fun () ->
      let speed =
        dist ~x1:(mouse_x ()) ~y1:(mouse_y ())
             ~x2:(pmouse_x ()) ~y2:(pmouse_y ())
      in
      let d = constrain ~lo:5. ~hi:46. (speed *. 1.6) in
      let hue = Float.rem (float_of_int (frame_count ()) *. 2.5) 360. in
      fill_hsb ~a:190 ~h:hue ~s:65. ~b:95. ();
      ellipse ~x:(mouse_x ()) ~y:(mouse_y ()) ~w:d ~h:d)

let () =
  mouse_pressed (fun () -> background ~r:250 ~g:250 ~b:252 ())
`,
  },

  {
    name: "Recursive tree",
    code: `(* Recursion plus push_matrix / pop_matrix. *)

let rec branch ~len ~depth =
  if depth > 0 then begin
    stroke_weight (float_of_int depth *. 0.7);
    line ~x1:0. ~y1:0. ~x2:0. ~y2:(-. len);

    push_matrix ();
    translate ~x:0. ~y:(-. len);
    rotate (radians 24.);
    branch ~len:(len *. 0.74) ~depth:(depth - 1);
    pop_matrix ();

    push_matrix ();
    translate ~x:0. ~y:(-. len);
    rotate (radians (-22.));
    branch ~len:(len *. 0.68) ~depth:(depth - 1);
    pop_matrix ()
  end

let () =
  size ~w:400. ~h:400.;
  background ~r:250 ~g:248 ~b:240 ();
  stroke ~r:74 ~g:56 ~b:44 ();
  push_matrix ();
  translate ~x:200. ~y:390.;
  branch ~len:92. ~depth:10;
  pop_matrix ()
`,
  },

  {
    name: "Perlin flow",
    code: `(* Perlin noise, sampled through time.
   [noise] keeps x positional, so ~y and ~z are optional extra dimensions. *)

let () =
  size ~w:400. ~h:400.;
  background ~r:16 ~g:17 ~b:22 ();
  no_stroke ();
  draw (fun () ->
      let t = float_of_int (frame_count ()) *. 0.006 in
      (* Fade the previous frame instead of clearing it. *)
      fill ~a:18 ~r:16 ~g:17 ~b:22 ();
      rect ~x:0. ~y:0. ~w:(width ()) ~h:(height ()) ();

      for i = 0 to 300 do
        let a = float_of_int i in
        let x = map_range ~src:(0., 1.) ~dst:(0., width ())
                  (noise ~y:t (a *. 0.06)) in
        let y = map_range ~src:(0., 1.) ~dst:(0., height ())
                  (noise ~y:(t +. 40.) (a *. 0.06 +. 90.)) in
        let hue = map_range ~src:(0., 1.) ~dst:(170., 330.)
                    (noise ~y:t (a *. 0.01)) in
        fill_hsb ~a:170 ~h:hue ~s:70. ~b:100. ();
        ellipse ~x ~y ~w:3.5 ~h:3.5
      done)
`,
  },

  {
    name: "Rainbow spiral",
    code: `let () =
  size ~w:400. ~h:400.;
  background ~r:255 ~g:255 ~b:255 ();
  no_stroke ();
  for i = 0 to 520 do
    let a = float_of_int i in
    let r = a *. 0.34 in
    let d = 3. +. (r *. 0.06) in
    fill_hsb ~h:(Float.rem (a *. 1.4) 360.) ~s:78. ~b:96. ();
    ellipse
      ~x:(200. +. (r *. cos (a *. 0.22)))
      ~y:(200. +. (r *. sin (a *. 0.22)))
      ~w:d ~h:d
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

let neighbours g ~x ~y =
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
          match g.(x).(y), neighbours g ~x ~y with
          | 1, (2 | 3) -> 1
          | 0, 3 -> 1
          | _ -> 0))

let world = ref (fresh ())

let () =
  size ~w:400. ~h:400.;
  mouse_pressed (fun () -> world := fresh ());
  draw ~fps:12. (fun () ->
      background ~r:15 ~g:17 ~b:21 ();
      no_stroke ();
      fill ~r:126 ~g:231 ~b:135 ();
      Array.iteri
        (fun x col ->
          Array.iteri
            (fun y v ->
              if v = 1 then
                rect
                  ~x:(float_of_int x *. cell)
                  ~y:(float_of_int y *. cell)
                  ~w:(cell -. 1.) ~h:(cell -. 1.) ())
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
  size ~w:400. ~h:400.;
  background ~r:255 ~g:255 ~b:255 ();
  text_size 13.;
  List.iteri
    (fun i n ->
      let y = 30. +. (float_of_int i *. 24.) in
      fill ~r:30 ~g:30 ~b:40 ();
      text ~x:20. ~y (Printf.sprintf "%2d" n);
      no_stroke ();
      fill ~a:140 ~r:90 ~g:150 ~b:230 ();
      rect ~x:60. ~y:(y -. 11.) ~w:(float_of_int n *. 0.6) ~h:14. ())
    first_15
`,
  },
];
