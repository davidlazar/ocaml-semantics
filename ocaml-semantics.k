module OCAML-SYNTAX-EXTRAS is

    syntax KResult ::= Int | Bool | Id

    syntax K
      ::= "initEnv"
        | "binding"
        | "matching"
        | "assigning"
        | "debug"


    syntax Loc ::= "loc" "(" Int ")"
    syntax KResult ::= Loc

    syntax KResult ::= "cons" "(" K ")"

    syntax K ::= "env" "(" Map ")"

end module

module OCAML-CONFIGURATION is
    including OCAML-SYNTAX
    including OCAML-SYNTAX-EXTRAS

    configuration
        <T>
            <k color="LightGreen"> initEnv ~> $PGM:K </k>
            <env color="LightSkyBlue"> .Map </env>
            <store color="LightSteelBlue"> .Map </store>
            <xstack color="LightSlateBlue"> .K </xstack>
            <nextLoc> 0 </nextLoc>
            <assign> .Map </assign>
            <br/>
            <matchAnalysis multiplicity="?" color="LightGoldenrod">
                <matchK color="PaleGreen"> matching </matchK>
                <cases> .K </cases>
                <scrutinee> .K </scrutinee>
                <expr> .K </expr>
            </matchAnalysis>
            <br/>
            <patternAttempts>
                <patternAttempt multiplicity="*">
                    <patterns color="Violet"> .Bag </patterns>
                    <subst color="GreenYellow"> .Map </subst>
                </patternAttempt>
            </patternAttempts>
        </T>
        <result multiplicity="?" color="DodgerBlue">
            <exprResult> .K </exprResult>
        </result>


end module

module OCAML-APPLICATION is
    including OCAML-SYNTAX

    syntax K ::= "apply" "(" K "," List{K} ")" [strict(1)]
    syntax K ::= "flattenApp" "(" K "," List{K} ")"

    rule ExApp(K1:K, K2:K) => flattenApp(ExApp(K1, K2), .List{K})

    rule flattenApp(ExApp(K:K, Arg:K), Args:List{K}) => flattenApp(K, Arg,, Args)
    rule flattenApp(K:K, Args:List{K}) => apply(K, Args)
        when getKLabel(K) =/=KLabel 'ExApp`(_`,_`)

end module

module OCAML-EXTERNAL is
    including OCAML-APPLICATION

    syntax K ::= "external" "(" K "," Int ")"
    syntax K ::= "externalClosure" "(" K "," Int "," List{K} ")"

    define 'isKResult(externalClosure(_, Arity:Int, _)) => true
        when Arity >Int 0

    rule
        external(Op:K, Arity:Int)
        => externalClosure(Op, Arity, .List{K})

    syntax External ::= "%undefined"

    context apply(externalClosure(_:External, _, _), _:List{K},, HOLE,, _:List{K}) [superheat]

    rule
        apply(externalClosure(Op:K, Arity:Int, Args:List{K}), NewArgs:List{K})
        => externalClosure(Op, Arity -Int lengthList{K}(NewArgs), (Args,, NewArgs))

    rule
        externalClosure(Op:K, 0, Args:List{K})
        => getKLabel(Op)(Args)

end module

module OCAML-INCLUDE is
    including OCAML-SYNTAX
    including OCAML-SYNTAX-EXTRAS
    including OCAML-CONFIGURATION
    including OCAML-APPLICATION
    including OCAML-EXTERNAL

end module

module OCAML-ARITHMETIC is
    including OCAML-INCLUDE

    rule ExInt(I:Int) => I

    syntax External
      ::= primAdd
        | primSubtract
        | primMultiply
        | primDivide
        | primNegate

    rule 'primAdd(I1:Int,, I2:Int) => I1 +Int I2
    rule 'primSubtract(I1:Int,, I2:Int) => I1 -Int I2
    rule 'primMultiply(I1:Int,, I2:Int) => I1 *Int I2
    rule 'primDivide(I1:Int,, I2:Int) => I1 /Int I2
    rule 'primNegate(I:Int) => 0 -Int I

end module

module OCAML-BOOLEANS is
    including OCAML-INCLUDE

    rule IdUid("False") => false
    rule IdUid("True") => true

    syntax External ::= primNot

    rule 'primNot(false) => true
    rule 'primNot(true) => false

    syntax LazyExternal ::= primAnd | primOr

    rule 'primAnd(Exp1:K,, Exp2:K) => ExIfe(Exp1, Exp2, false)
    rule 'primOr(Exp1:K,, Exp2:K) => ExIfe(Exp1, true, Exp2)

end module

module OCAML-CONTROL-FLOW is
    including OCAML-INCLUDE

    rule ExIfe(true, Exp:K, _) => Exp
    rule ExIfe(false, _, Exp:K) => Exp

    rule
        <k> ExSeq(K:K) => K ...</k>

    rule
        <k> ExSem(V:KResult, Exp:K) => Exp ...</k>

end module

module OCAML-LET-LETREC is
    including OCAML-INCLUDE

    //@ Variable lookup
    rule
        <k> ExId(LId:LId) => K ...</k>
        <env>... LId |-> L:Loc ...</env>
        <store>... L |-> K:K ...</store>


    syntax K ::= "group" "(" K "," K ")"
    syntax K ::= "letbody" "(" K ")"

    // TODO this can probably be better
    rule
        <k> ExLet(Binding:K, Exp:K)
            => group(ExId(IdUid("()")), PaId(IdUid("()")))
            ~> Binding ~> letbody(Exp) ~> env(Env) ...</k>
        <env> Env:Map </env>

    rule
        <k> group(_, _) ~> (BiAnd(Binding1:K, Binding2:K) => Binding1 ~> Binding2) ...</k>

    rule
        <k> group(Exp1:K, Pat1:K) ~> BiEq(Pat2:K, Exp2:K)
            => group(ExCom(Exp1, Exp2), PaCom(Pat1, Pat2))
        ...</k>

    rule
        <k> group(Exp1:K, Pat:K) ~> letbody(Exp2:K)
            => ExMat(Exp1, McArr(Pat, ExNil, Exp2))
        ...</k>

    syntax K ::= "recbind" "(" K ")"
    syntax K ::= "assign" "(" K ")"

    context assign(BiEq(_, HOLE))

    rule
        <k> ExLetRec(Binding:K, Exp:K) => recbind(Binding) ~> assign(Binding) ~> Exp ~> env(Env) ...</k>
        <env> Env:Map </env>

    rule
        <k> recbind(BiAnd(Binding1:K, Binding2:K)) => recbind(Binding1) ~> recbind(Binding2) ...</k>

    rule
        <k> assign(BiAnd(Binding1:K, Binding2:K)) => assign(Binding1) ~> assign(Binding2) ...</k>

    rule
        <k> recbind(BiEq(PaId(X:Id), _)) => . ...</k>
        <env> Env:Map => Env[loc(N) / X] </env>
        <nextLoc> N:Int => N +Int 1 </nextLoc>

    rule
        <k> assign(BiEq(PaId(X:Id), V:KResult)) => . ...</k>
        <env>... X |-> L:Loc ...</env>
        <store>... . => L |-> V ...</store>

end module

module OCAML-FUNCTIONS is
    including OCAML-INCLUDE

    rule
        <k> ExId(UId:UId) => UId ...</k>

    rule
        <k> ExApp(UId:UId, V:KResult) => cons(ExApp(UId, V)) ...</k>

    rule
        <k> ExApp(cons(K:K), V:KResult) => cons(ExApp(K, V)) ...</k>

    syntax KResult ::= "closure" "(" Map "," K ")"

    context apply(closure(_, _), _:List{K},, HOLE,, _:List{K})

    rule
        <k> ExFun(MC:K) => closure(Env, MC) ...</k>
        <env> Env:Map </env>

    rule
        <k> apply(closure(Env':Map, MC:K), V:KResult) => ExMat(V, MC) ~> env(Env) ...</k>
        <env> Env => Env' </env>

    rule
        <k> apply(closure(Env':Map, MC:K), V:KResult,, Args:List{KResult}) => apply(ExMat(V, MC), Args) ~> env(Env) ...</k>
        <env> Env => Env' </env>

end module

module OCAML-EXCEPTIONS is
    including OCAML-INCLUDE

    syntax External ::= primRaise

    syntax K ::= "x" "(" K "," K "," Map ")"
    syntax K ::= "popx"

    rule
        <k> (ExTry(Exp:K, MC:K) => Exp ~> popx) ~> K:K </k>
        <env> Env:Map </env>
        <xstack> . => x(K, MC, Env) ...</xstack>

    rule
        <k> V:KResult ~> popx => V ...</k>
        <xstack> K:K => . ...</xstack>

    rule
        <k> 'primRaise(V:KResult) ~> _ => ExMat(V, McOr(MC, McArr(PaAny, ExNil, 'primRaise(V)))) ~> K </k>
        <xstack> x(K:K, MC:K, Env:Map) => . ...</xstack>
        <env> _ => Env </env>

end module

module OCAML-MUTABLES is
    including OCAML-INCLUDE

    syntax External
      ::= primRef
        | primAssign

    // "val" isn't really an external
    syntax KResult ::= primVal

    rule
        <k> 'primRef(V:KResult) => loc(N) ...</k>
        <store>... . => loc(N) |-> V ...</store>
        <nextLoc> N:Int => N +Int 1 </nextLoc>

    context ExAss(ExAcc(HOLE, _), _)
    context ExAss(ExAcc(_, HOLE), _)

    rule
        <k> ExAss(ExAcc(L:Loc, primVal), V:KResult) => 'primAssign(L,, V) ...</k>

    rule
        <k> 'primAssign(L:Loc,, V:KResult) => ExId(IdUid("()")) ...</k>
        <store>... L |-> (_ => V) ...</store>

    rule
        <k> ExAcc(L:Loc, primVal) => V ...</k>
        <store>... L |-> V ...</store>

end module

module OCAML-PATTERNS is
    including OCAML-INCLUDE

    syntax BagItem ::= K "<-" K

    syntax BagItem ::= "pattern-failure" "(" K "," K ")"

    rule
        <patterns>... PaInt(I:Int) <- I => . ...</patterns>

    rule
        <patterns>... PaId(X:LId) <- K:K => . ...</patterns>
        <subst>... . => X |-> K ...</subst>

    rule
        <patterns>... PaAny <- K:K => . ...</patterns>

    rule
        <patterns>... PaTup(Pat:K) <- ExTup(Exp:K) => Pat <- Exp ...</patterns>

    rule
        <patterns>... PaId(UId:UId) <- UId => . ...</patterns>

    rule
        <patterns>...
            PaCom(Pat1:K, Pat2:K) <- ExCom(Exp1:K, Exp2:K) =>
                (Pat1 <- Exp1)
                (Pat2 <- Exp2)
        ...</patterns>

    rule
        <patterns>... PaAli(Pat:K, PaId(X:Id)) <- Exp:K => Pat <- Exp ...</patterns>
        <subst>... . => X |-> Exp ...</subst>

    rule
        <patternAttempt>...
            <patterns> (PaOrp(Pat1:K, Pat2:K) <- Exp:K) Rest:Bag </patterns>
            <subst> Subst:Map </subst>
        ...</patternAttempt>
        =>
        <patternAttempt>...
            <patterns> (Pat1 <- Exp) Rest </patterns>
            <subst> Subst </subst>
        ...</patternAttempt>
        <patternAttempt>...
            <patterns> (Pat2 <- Exp) Rest </patterns>
            <subst> Subst </subst>
        ...</patternAttempt>

    rule
        <patterns> (Pat <- K) Rest:Bag => pattern-failure(Pat, K) </patterns>
        when notBool (matches K Pat)

    rule
        <patternAttempt>...
            <patterns> pattern-failure(_, _) </patterns>
        ...</patternAttempt>
        => .

    /*@ Unfortunately, we have to define the predicate below since we don't
    have a way of saying "when no other rule matches" */
    op matches__ : K K -> Bool
    eq matches _ PaId(LId:LId) = true
    eq matches UId:UId PaId(UId) = true
    eq matches cons(_) _ = true
    eq matches _ PaAny = true
    eq matches _ PaAli(_, _) = true
    eq matches _ PaTyc(_, _) = true
    eq matches _ PaOrp(_, _) = true
    eq matches ExTup(_) PaTup(_) = true
    eq matches ExCom(_, _) PaCom(_, _) = true
    eq matches I:Int PaInt(I) = true
    eq matches . . = true
    eq matches _ _ = false [owise]

end module

module OCAML-MATCHING is
    including OCAML-INCLUDE
    including OCAML-PATTERNS

    rule
        <k> ExMat(V:KResult, MC:K) => matching ...</k>
        (. =>
            <matchAnalysis>...
                <cases> MC </cases>
                <scrutinee> V </scrutinee>
            ...</matchAnalysis>
        )

    rule
        <k> matching => assigning ~> K ~> env(Env) ...</k>
        <env> Env:Map </env>
        <assign> . => Subst </assign>
        <matchK> match-success(K:K, Subst:Map) => . </matchK>

    syntax K
      ::= "match-failure"
        | "match-success" "(" K "," Map ")"

    rule
        <cases> McOr(MC1:K, MC2:K) => MC1 ~> MC2 ...</cases>

    rule
        <matchK> matching => binding </matchK>
        <cases> McArr(Pat:K, _, Exp:K) => . ...</cases>
        <scrutinee> V:KResult </scrutinee>
        <expr> _ => Exp </expr>
        <patternAttempts>
            (_ =>
                <patternAttempt>...
                    <patterns> Pat <- V </patterns>
                ...</patternAttempt>
            )
        </patternAttempts>

    rule
        <matchK> binding => matching </matchK>
        <patternAttempts> .Bag </patternAttempts>

    rule
        <matchK> binding => match-success(Exp, Subst) </matchK>
        <patternAttempts>
            (<patternAttempt>
                <patterns> . </patterns>
                <subst> Subst:Map </subst>
            </patternAttempt>
            Rest:Bag) => .
        </patternAttempts>
        <expr> Exp:K => . </expr>

    rule
        <matchK> matching => match-failure </matchK>
        <cases> . </cases>

    rule
        <matchAnalysis>...
            <matchK> .K </matchK>
        ...</matchAnalysis>
        => .

end module

module OCAML-TOP-LEVEL is
    //@ Top-level phrases in an OCaml module (also known as structure items?)
    including OCAML-INCLUDE

    rule
        <k> StSem(K1:K, K2:K) => K1 ~> K2 ...</k>

    //@ Ignore exception definitions since we assume the program type checks
    rule
        <k> StExc(_, _) => . ...</k>

    rule
        <k> StExp(Exp:K) => Exp ...</k>

end module

module OCAML-HELPERS is
    including OCAML-INCLUDE

    rule
        <assign> X:Id |-> K:K => . ...</assign>
        <env> Env:Map => Env[loc(N) / X] </env>
        <store>... . => loc(N) |-> K ...</store>
        <nextLoc> N:Int => N +Int 1 </nextLoc>

    rule
        <k> assigning => . ...</k>
        <assign> . </assign>

    rule
        <k> V:KResult ~> (env(Env:Map) => .) ...</k>
        <env> _ => Env </env>

end module

module OCAML-INIT is
    including OCAML-INCLUDE
    including OCAML-ARITHMETIC
    including OCAML-BOOLEANS
    including OCAML-MUTABLES
    including OCAML-EXCEPTIONS

    rule
        <k> initEnv => assigning ...</k>
        <assign> . =>
            IdLid("~-") |-> external(primNegate, 1)
            IdLid("raise") |-> external(primRaise, 1)
            IdLid("+") |-> external(primAdd, 2)
            IdLid("-") |-> external(primSubtract, 2)
            IdLid("*") |-> external(primMultiply, 2)
            IdLid("/") |-> external(primDivide, 2)

            IdLid("not") |-> external(primNot, 1)
            IdLid("&&") |-> external(primAnd, 2)
            IdLid("||") |-> external(primOr, 2)

            IdLid("ref") |-> external(primRef, 1)
            IdLid("val") |-> primVal
        </assign>

end module

module OCAML-CLEANUP is
    including OCAML-INCLUDE

    rule
        <T>...
            <k> V:KResult </k>
        ...</T>
        =>
        <result>...
            <exprResult> V </exprResult>
        ...</result>

end module

module OCAML-SEMANTICS is
    including OCAML-INCLUDE

    including OCAML-ARITHMETIC
    including OCAML-BOOLEANS
    including OCAML-CONTROL-FLOW
    including OCAML-LET-LETREC
    including OCAML-FUNCTIONS
    including OCAML-EXCEPTIONS
    including OCAML-MUTABLES
    including OCAML-PATTERNS
    including OCAML-MATCHING

    including OCAML-TOP-LEVEL

    including OCAML-HELPERS
    including OCAML-INIT
    including OCAML-CLEANUP

end module
