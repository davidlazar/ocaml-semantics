(* test short-circuiting *)
let x = ref 0 and y = ref 0 in false && (x := 1; true); true || (y := 1; false); !x + !y
