(** A Processing / ProcessingJS ("Khan Academy") style drawing library.

    The playground opens this module by default:

    {[
      size ~w:400. ~h:400.;
      background ~r:255 ~g:255 ~b:255 ();
      fill ~r:255 ~g:0 ~b:0 ();
      ellipse ~x:200. ~y:200. ~w:120. ~h:120.
    ]}

    {2 Conventions}

    Every value argument is labelled, so there is no argument order to remember
    and no way to transpose [w] and [h] silently. Two consequences worth
    knowing:

    - Where one value is clearly the subject it stays positional, and last:
      [text ~x:20. ~y:30. "hello"], [noise ~y:t 0.5], [draw (fun () -> ...)].
    - A function that takes several coequal values {e and} an optional argument
      ends in [()] — [fill ~r:255 ~g:0 ~b:0 ()]. OCaml can only drop an
      optional argument when a positional one follows it, so without the [()]
      the call would quietly be a partial application. The seven such functions
      are [fill], [stroke], [background], [fill_hsb], [stroke_hsb], [rect] and
      [square].

    {2 Numbers}

    A value is an [int] when it counts something or lands on the pixel grid and
    is never meaningfully fractional: canvas [size], text placement and size,
    frame rates, colour channels (0..255), seeds. It is a [float] when it is
    geometry — anything that gets computed, interpolated, rotated or animated.

    Shape coordinates are therefore [float]s, as they are in Processing, p5.js
    and the canvas API itself: they come out of trigonometry, Perlin noise,
    [mouse_x ()] and accumulating velocity, and the canvas anti-aliases
    sub-pixel positions, so rounding them makes slow motion visibly steppy.

    Angles are radians. *)

(** {1 Canvas} *)

val size : w:int -> h:int -> unit
(** Resizes the sketch. Defaults to 400x400. *)

val width : unit -> float
val height : unit -> float
(** Returned as [float]s: unlike the canvas dimensions you {e set}, these are
    almost always read back into coordinate arithmetic. *)

val background : ?a:int -> r:int -> g:int -> b:int -> unit -> unit
(** Paints over the whole canvas. *)

val background_gray : ?a:int -> int -> unit
val clear : unit -> unit

(** {1 Style} *)

type mode = [ `Corner | `Corners | `Center | `Radius ]
type h_align = [ `Left | `Center | `Right ]
type v_align = [ `Top | `Middle | `Baseline | `Bottom ]
type cap = [ `Round | `Square | `Project ]
type join = [ `Miter | `Bevel | `Round ]

val fill : ?a:int -> r:int -> g:int -> b:int -> unit -> unit
val fill_gray : ?a:int -> int -> unit

val fill_hsb : ?a:int -> h:float -> s:float -> b:float -> unit -> unit
(** Hue in 0..360, saturation and brightness in 0..100. *)

val no_fill : unit -> unit
val stroke : ?a:int -> r:int -> g:int -> b:int -> unit -> unit
val stroke_gray : ?a:int -> int -> unit
val stroke_hsb : ?a:int -> h:float -> s:float -> b:float -> unit -> unit
val no_stroke : unit -> unit
val stroke_weight : float -> unit
val stroke_cap : cap -> unit
val stroke_join : join -> unit

val rect_mode : mode -> unit
(** How [rect]'s four values are read. Defaults to [`Corner]. *)

val ellipse_mode : mode -> unit
(** How [ellipse]'s four values are read. Defaults to [`Center]. *)

(** {1 Shapes} *)

val point : x:float -> y:float -> unit
val line : x1:float -> y1:float -> x2:float -> y2:float -> unit

val rect : ?r:float -> x:float -> y:float -> w:float -> h:float -> unit -> unit
(** [?r] rounds the corners. *)

val square : ?r:float -> x:float -> y:float -> s:float -> unit -> unit
val ellipse : x:float -> y:float -> w:float -> h:float -> unit
val circle : x:float -> y:float -> d:float -> unit

val arc :
  x:float -> y:float -> w:float -> h:float -> start:float -> stop:float -> unit
(** The fill is a pie slice, the stroke is the arc itself. *)

val triangle :
  x1:float -> y1:float -> x2:float -> y2:float -> x3:float -> y3:float -> unit

val quad :
     x1:float -> y1:float -> x2:float -> y2:float
  -> x3:float -> y3:float -> x4:float -> y4:float
  -> unit

val bezier :
     x1:float -> y1:float -> cx1:float -> cy1:float
  -> cx2:float -> cy2:float -> x2:float -> y2:float
  -> unit
(** Stroked only. *)

val begin_shape : unit -> unit
val vertex : x:float -> y:float -> unit

val bezier_vertex :
     cx1:float -> cy1:float -> cx2:float -> cy2:float -> x:float -> y:float
  -> unit
(** Continues the current shape with a cubic segment. *)

val end_shape : ?close:bool -> unit -> unit

(** {1 Transforms} *)

val push_matrix : unit -> unit
(** Saves the transform {e and} the current style. *)

val pop_matrix : unit -> unit
val translate : x:float -> y:float -> unit
val rotate : float -> unit

val scale : ?y:float -> float -> unit
(** [scale 2.] is uniform; [scale ~y:0.5 2.] is not. *)

val reset_matrix : unit -> unit

(** {1 Text} *)

val text : ?size:int -> ?align:h_align -> x:int -> y:int -> string -> unit
(** Text sits on the pixel grid, so its placement and size are [int]s.
    [?size] and [?align] apply to this call only. *)

val text_size : int -> unit

val text_font : string -> unit
(** Any CSS font family, e.g. ["Roboto Mono"]. *)

val text_align : ?v:v_align -> h_align -> unit
val text_width : string -> int

(** {1 Maths} *)

val pi : float
val two_pi : float
val half_pi : float

val random : ?min:float -> float -> float
(** [random ~min:lo hi] in \[lo, hi). [min] defaults to 0. *)

val random_int : ?min:int -> int -> int
val random_seed : int -> unit

val noise : ?y:float -> ?z:float -> float -> float
(** Perlin noise in 1, 2 or 3 dimensions, returning 0..1. *)

val noise_seed : int -> unit
val dist : x1:float -> y1:float -> x2:float -> y2:float -> float
val mag : x:float -> y:float -> float
val lerp : a:float -> b:float -> t:float -> float
val norm : lo:float -> hi:float -> float -> float

val map_range : src:float * float -> dst:float * float -> float -> float
(** [map_range ~src:(0., 1.) ~dst:(0., 400.) v] re-ranges [v]. *)

val constrain : lo:float -> hi:float -> float -> float
val radians : float -> float
val degrees : float -> float
val sq : float -> float

(** {1 The draw loop} *)

val draw : ?fps:int -> (unit -> unit) -> unit
(** [draw f] runs [f] once per frame. An exception escaping [f] is reported on
    stderr and stops the sketch. *)

val no_loop : unit -> unit
val loop : unit -> unit
val frame_rate : int -> unit
val frame_count : unit -> int

val millis : unit -> float
(** Milliseconds since the sketch started. *)

(** {1 Mouse and keyboard} *)

val mouse_x : unit -> float
val mouse_y : unit -> float

val pmouse_x : unit -> float
(** Where the mouse was on the previous frame. *)

val pmouse_y : unit -> float
val mouse_is_pressed : unit -> bool
val key_is_pressed : unit -> bool
val key_char : unit -> string
val key_code : unit -> int
val mouse_pressed : (unit -> unit) -> unit
val mouse_released : (unit -> unit) -> unit
val mouse_moved : (unit -> unit) -> unit
val mouse_dragged : (unit -> unit) -> unit
val mouse_clicked : (unit -> unit) -> unit
val key_pressed : (unit -> unit) -> unit
val key_released : (unit -> unit) -> unit

(** {1 Lifecycle} *)

val reset : unit -> unit
(** Stops the sketch, drops every handler, restores the default style and
    clears the canvas. The playground calls this before each run. *)
