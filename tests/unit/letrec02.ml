let rec fac n = match n with 0 -> 1 | _ -> n * fac (n - 1) in 3628800 - fac 10
