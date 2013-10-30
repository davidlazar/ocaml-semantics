let x = 1 and y = 2 in let rec f x = x + y () + 1 and y = fun _ -> x and x = 3 in f x - 7
