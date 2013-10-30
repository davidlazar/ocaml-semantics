let rec f = function 0 -> 0 | x -> f (x - 1) in f 42
