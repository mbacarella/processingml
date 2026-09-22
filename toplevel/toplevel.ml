(* The js_of_ocaml toplevel driver behind the playground.

   It exposes a tiny JS API on [window.OCamlTop]:

     OCamlTop.init()            -> starts the toplevel, returns the OCaml version
     OCamlTop.setSink(fn)       -> fn(kind, text) receives all output;
                                   kind is "out" | "err" | "result"
     OCamlTop.exec(code, reset) -> runs a chunk of OCaml source
     OCamlTop.reset()           -> tears the current sketch down
     OCamlTop.noLoop() / loop() -> pause and resume the draw loop

   Output is streamed through the sink rather than returned, so that anything a
   sketch prints from its draw loop shows up in the console too. *)

open Js_of_ocaml
open Js_of_ocaml_toplevel

let sink : Js.Unsafe.any option ref = ref None

let emit kind s =
  if String.length s > 0 then
    match !sink with
    | None -> ()
    | Some cb ->
        ignore
          (Js.Unsafe.fun_call cb
             [| Js.Unsafe.inject (Js.string kind); Js.Unsafe.inject (Js.string s) |])

let formatter_of kind =
  Format.make_formatter
    (fun buf pos len -> emit kind (String.sub buf pos len))
    (fun () -> ())

let result_ppf = formatter_of "result"
let err_ppf = formatter_of "err"
let initialized = ref false

let flush_all_channels () =
  (try flush stdout with _ -> ());
  (try flush stderr with _ -> ());
  Format.pp_print_flush result_ppf ()

let initialize () =
  if not !initialized then begin
    initialized := true;
    Sys_js.set_channel_flusher stdout (fun s -> emit "out" s);
    Sys_js.set_channel_flusher stderr (fun s -> emit "err" s);
    JsooTop.initialize ();
    (* Route the toplevel's own error reporting to the console pane. *)
    Location.formatter_for_warnings := err_ppf;
    (try Random.self_init () with _ -> ());
    (* Make the drawing library available without any [open]. *)
    ignore (JsooTop.use result_ppf "open Processing;;" : bool);
    flush_all_channels ()
  end;
  Js.string Sys.ocaml_version

(* [Toploop.parse_toplevel_phrase] wants ";;"-terminated phrases, while people
   write playground code the way they'd write a file. *)
let terminate code =
  let trimmed = String.trim code in
  if trimmed = "" then trimmed
  else if String.length trimmed >= 2 && String.sub trimmed (String.length trimmed - 2) 2 = ";;"
  then trimmed
  else trimmed ^ "\n;;"

let exec code reset =
  if Js.to_bool reset then Processing.reset ();
  let code = terminate (Js.to_string code) in
  if code <> "" then begin
    (try JsooTop.execute true result_ppf code
     with e -> emit "err" (Printexc.to_string e ^ "\n"));
    flush_all_channels ()
  end

let () =
  let api = Js.Unsafe.obj [||] in
  let set name v = Js.Unsafe.set api (Js.string name) v in
  set "init" (Js.wrap_callback (fun () -> initialize ()));
  set "setSink" (Js.wrap_callback (fun cb -> sink := Some cb));
  set "exec" (Js.wrap_callback (fun code reset -> exec code reset));
  set "reset" (Js.wrap_callback (fun () -> Processing.reset ()));
  set "noLoop" (Js.wrap_callback (fun () -> Processing.no_loop ()));
  set "loop" (Js.wrap_callback (fun () -> Processing.loop ()));
  set "version" (Js.string Sys.ocaml_version);
  Js.Unsafe.set Js.Unsafe.global (Js.string "OCamlTop") api
