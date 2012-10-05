module OCAML-SYNTAX is

    syntax O ::= `Loc "(" K "," K ")" // LocInfo, K
    syntax O ::= `LocInfo "(" Int "," Int ")" // start, stop

    syntax LId ::= `IdLid "(" String ")"
    syntax UId ::= `IdUid "(" String ")"

    syntax Id ::= LId | UId
    syntax O ::= Id

    syntax O ::= `PaId "(" Id ")"
    syntax O ::= `PaInt "(" Int ")"
    syntax O ::= `PaAny
    syntax O ::= `PaAli "(" K "," K ")"
    syntax O ::= `PaTyc "(" K "," K ")"
    syntax O ::= `PaTup "(" K ")"
    syntax O ::= `PaCom "(" K "," K ")"
    syntax O ::= `PaOrp "(" K "," K ")"
    syntax O ::= `PaApp "(" K "," K ")"

    syntax O ::= `McOr "(" K "," K ")"
    syntax O ::= `McArr "(" K "," K "," K ")"

    syntax O ::= `BiAnd "(" K "," K ")"
    syntax O ::= `BiEq "(" K "," K ")" // pat = v

    syntax O ::= `ExNil
    syntax O ::= `ExId "(" K ")" // id
    syntax O ::= `ExInt "(" Int ")"
    syntax O ::= `ExApp "(" K "," K ")" [strict(1)] // e1 e2
    syntax O ::= `ExTup "(" K ")" [strict hybrid]
    syntax O ::= `ExCom "(" K "," K ")" [strict hybrid]
    syntax O ::= `ExMat "(" K "," K ")" [strict(1)] // value, match-case
    syntax O ::= `ExFun "(" K ")" // match-case
    syntax O ::= `ExSeq "(" K ")" // sequencing?
    syntax O ::= `ExSem "(" K "," K ")" [strict(1)] // e1 ; e2
    syntax O ::= `ExIfe "(" K "," K "," K ")" [strict(1)] // if e1 then e1 else e3
    syntax O ::= `ExAss "(" K "," K ")" // e1 := e2
    syntax O ::= `ExAcc "(" K "," K ")" [strict] // e1.e2 (access)
    syntax O ::= `ExLet "(" K "," K ")"
    syntax O ::= `ExLetRec "(" K "," K ")"
    syntax O ::= `ExTry "(" K "," K ")"

    syntax O ::= `StExp "(" K ")" // expr
    syntax O ::= `StSem "(" K "," K ")" // st1 ;; st2
    syntax O ::= `StExc "(" K "," K ")" // exception

    syntax O ::= `TyId "(" K ")"

    // option types are sometimes used in the AST
    // TODO maybe we should fix this?
    syntax O ::= "None"

end module
