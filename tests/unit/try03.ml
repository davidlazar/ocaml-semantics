exception E1;;
exception E2;;
try (1, raise E1) with E2 -> 23 | _ -> 42
