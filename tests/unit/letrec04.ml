let rec even = function 0 -> true | n -> odd (n - 1) and odd = function 0 -> false | n -> even (n - 1) in if even 12 && not (even 9) then 0 else 1
