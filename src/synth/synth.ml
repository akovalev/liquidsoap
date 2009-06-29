let pi = 3.1416

let freq_of_note n = 440. *. (2. ** ((float n -. 69.) /. 12.))

class type synth =
object
  method note_on : int -> float -> unit

  method note_off : int -> float -> unit

  method synth : float -> float array array -> int -> int -> unit
end

(* Global state and note state. *)
class virtual ['gs,'ns] base =
object (self)
  val mutable state = None

  method state =
    match state with
      | Some s -> s
      | None -> assert false

  val mutable notes = []

  method virtual state_init : 'gs

  method virtual note_init : int -> float -> 'ns

  method init =
    state <- Some (self#state_init)

  initializer
    self#init

  method note_on n v =
    notes <- (n, ref (self#note_init n v))::notes

  method note_off n (v:float) =
    (* TODO: remove only one note *)
    notes <- List.filter (fun (m, _) -> m <> n) notes

  method synth_note_mono (gs:'gs) (ns:'ns) (freq:float) (buf:float array) (ofs:int) (len:int) = gs, ns

  method synth_note gs ns freq buf ofs len =
    let s = ref None in
    let chans = Array.length buf in
      for c = 0 to chans - 1 do
        s := Some (self#synth_note_mono gs ns freq buf.(c) ofs len)
      done;
      match !s with
        | Some s -> s
        | None -> gs, ns

  method synth freq buf ofs len =
    let gs = ref self#state in
      List.iter
        (fun (_, ns) ->
           let gs', ns' = self#synth_note self#state !ns freq buf ofs len in
             gs := gs';
             ns := ns'
        ) notes;
      state <- Some !gs
end

type simple_gs = unit
(* Period is 1. *)
type simple_ns =
    {
      simple_phase : float;
      simple_freq : float;
      simple_ampl : float;
    }

class simple f =
object (self)
  inherit [simple_gs, simple_ns] base

  method state_init = ()

  method note_init n v = { simple_phase = (*Random.float 1.*) 0.; simple_freq = freq_of_note n; simple_ampl = v }

  method synth_note_mono gs ns freq buf ofs len =
    let phase i = ns.simple_phase +. float i /. freq *. ns.simple_freq in
      for i = ofs to ofs + len - 1 do
        buf.(i) <- buf.(i) +. ns.simple_ampl *. f (phase i)
      done;
      gs, { ns with simple_phase = fst (modf (phase len)) }
end

class sine = object inherit simple (fun x -> sin (x *. 2. *. pi)) end

class square = object inherit simple (fun x -> let x = fst (modf x) in if x < 0.5 then 1. else -1.) end