(** A Processing / ProcessingJS ("Khan Academy") style drawing library.

    The playground opens this module by default, so sketches read the way they
    do in Processing:

    {[
      size 400. 400.;
      background 255 255 255;
      fill 255 0 0;
      ellipse 200. 200. 120. 120.
    ]}

    Geometry is in [float]s, as in Processing. Colour channels are [int]s in
    0..255, and every colour function takes an optional [?a] alpha in the same
    range. Angles are radians. *)

(** {1 Canvas} *)

val size : float -> float -> unit
(** [size w h] resizes the sketch. Defaults to 400x400. *)

val width : unit -> float
val height : unit -> float

val background : ?a:int -> int -> int -> int -> unit
(** Paints over the whole canvas. *)

val background_gray : ?a:int -> int -> unit
val clear : unit -> unit

(** {1 Style} *)

type mode = [ `Corner | `Corners | `Center | `Radius ]
type h_align = [ `Left | `Center | `Right ]
type v_align = [ `Top | `Middle | `Baseline | `Bottom ]
type cap = [ `Round | `Square | `Project ]
type join = [ `Miter | `Bevel | `Round ]

val fill : ?a:int -> int -> int -> int -> unit
val fill_gray : ?a:int -> int -> unit

val fill_hsb : ?a:int -> float -> float -> float -> unit
(** [fill_hsb h s b] with hue in 0..360 and saturation/brightness in 0..100. *)

val no_fill : unit -> unit
val stroke : ?a:int -> int -> int -> int -> unit
val stroke_gray : ?a:int -> int -> unit
val stroke_hsb : ?a:int -> float -> float -> float -> unit
val no_stroke : unit -> unit
val stroke_weight : float -> unit
val stroke_cap : cap -> unit
val stroke_join : join -> unit

val rect_mode : mode -> unit
(** How [rect]'s four arguments are read. Defaults to [`Corner]. *)

val ellipse_mode : mode -> unit
(** How [ellipse]'s four arguments are read. Defaults to [`Center]. *)

(** {1 Shapes} *)

val point : float -> float -> unit
val line : float -> float -> float -> float -> unit
val rect : float -> float -> float -> float -> unit
val rect_rounded : float -> float -> float -> float -> float -> unit
val square : float -> float -> float -> unit
val ellipse : float -> float -> float -> float -> unit
val circle : float -> float -> float -> unit

val arc : float -> float -> float -> float -> float -> float -> unit
(** [arc x y w h start stop]. The fill is a pie slice, the stroke is the arc. *)

val triangle : float -> float -> float -> float -> float -> float -> unit

val quad :
  float -> float -> float -> float -> float -> float -> float -> float -> unit

val bezier :
  float -> float -> float -> float -> float -> float -> float -> float -> unit
(** [bezier x1 y1 cx1 cy1 cx2 cy2 x2 y2] — stroked only. *)

val begin_shape : unit -> unit
val vertex : float -> float -> unit

val bezier_vertex :
  float -> float -> float -> float -> float -> float -> unit
(** [bezier_vertex cx1 cy1 cx2 cy2 x y] continues the current shape. *)

val end_shape : ?close:bool -> unit -> unit

(** {1 Transforms} *)

val push_matrix : unit -> unit
(** Saves the transform {e and} the current style. *)

val pop_matrix : unit -> unit
val translate : float -> float -> unit
val rotate : float -> unit
val scale : float -> unit
val scale_xy : float -> float -> unit
val reset_matrix : unit -> unit

(** {1 Text} *)

val text : string -> float -> float -> unit
val text_size : float -> unit

val text_font : string -> unit
(** Any CSS font family, e.g. ["Roboto Mono"]. *)

val text_align : ?v:v_align -> h_align -> unit
val text_width : string -> float

(** {1 Maths} *)

val pi : float
val two_pi : float
val half_pi : float

val random : ?min:float -> float -> float
(** [random ~min:lo hi] in \[lo, hi). [min] defaults to 0. *)

val random_int : int -> int -> int
(** [random_int lo hi] in \[lo, hi). *)

val random_seed : int -> unit

val noise : ?y:float -> ?z:float -> float -> float
(** Perlin noise in 1, 2 or 3 dimensions, returning 0..1. *)

val noise_seed : int -> unit
val dist : float -> float -> float -> float -> float
val mag : float -> float -> float
val lerp : float -> float -> float -> float
val norm : float -> float -> float -> float

val map_range : float -> float -> float -> float -> float -> float
(** [map_range v lo1 hi1 lo2 hi2] re-ranges [v]. *)

val constrain : float -> float -> float -> float
val radians : float -> float
val degrees : float -> float
val sq : float -> float

(** {1 The draw loop} *)

val draw : (unit -> unit) -> unit
(** [draw f] runs [f] once per frame. An exception escaping [f] is reported on
    stderr and stops the sketch. *)

val no_loop : unit -> unit
val loop : unit -> unit
val frame_rate : float -> unit
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
