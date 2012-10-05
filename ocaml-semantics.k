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
            <patternAnalysis multiplicity="?" color="LightGoldenrod">
                <bindK color="PaleGreen"> binding </bindK>
                <bindAttempts>
                    <bindAttempt multiplicity="*">
                        <pattern color="Violet"> .K </pattern>
                        <value color="GreenYellow"> .K </value>
                        <subst> .Map </subst>
                    </bindAttempt>
                </bindAttempts>
            </patternAnalysis>
        </T>
        <result multiplicity="?" color="DodgerBlue">
            <exprResult> .K </exprResult>
        </result>


end module

module OCAML-INCLUDE is
    including OCAML-SYNTAX
    including OCAML-SYNTAX-EXTRAS
    including OCAML-CONFIGURATION

end module

module OCAML-PRIM-OPS is
    including OCAML-INCLUDE

    syntax UnaryPrimOp
      ::= primNegate
        | primNot
        | primRef
        | primRaise

    syntax BinaryPrimOp
      ::= StrictBinaryPrimOp
        | primAnd
        | primOr

    syntax StrictBinaryPrimOp
      ::= primAdd
        | primSubtract
        | primMultiply
        | primDivide
        | primAssign

    syntax KResult ::= UnaryPrimOp | BinaryPrimOp

    rule 'primNegate(I:Int) => 0 -Int I
    rule 'primAdd(I1:Int,, I2:Int) => I1 +Int I2
    rule 'primSubtract(I1:Int,, I2:Int) => I1 -Int I2
    rule 'primMultiply(I1:Int,, I2:Int) => I1 *Int I2
    rule 'primDivide(I1:Int,, I2:Int) => I1 /Int I2

    rule IdUid("False") => false
    rule IdUid("True") => true
    rule 'primNot(false) => true
    rule 'primNot(true) => false

    /* short-circuiting boolean operators */
    rule ExApp(primClosure(primAnd, Exp1:K), Exp2:K) => ExIfe(Exp1, Exp2, false)
    rule ExApp(primClosure(primOr, Exp1:K), Exp2:K) => ExIfe(Exp1, true, Exp2)


    context ExApp(UOp:UnaryPrimOp, HOLE)

    rule
        <k> ExApp(UOp:UnaryPrimOp, V:KResult) => getKLabel(UOp)(V) ...</k>

    syntax KResult ::= primClosure "(" K "," K ")"

    context ExApp(primClosure(SBOp:StrictBinaryPrimOp, HOLE), _)
    context ExApp(primClosure(SBOp:StrictBinaryPrimOp, _), HOLE)

    rule
        <k> ExApp(BOp:BinaryPrimOp, K:K) => primClosure(BOp, K)
        ...</k>

    rule
        <k> ExApp(primClosure(BOp:BinaryPrimOp, V1:KResult), V2:KResult)
            => getKLabel(BOp)(V1,,V2)
        ...</k>

end module

module OCAML-INIT is
    including OCAML-INCLUDE
    including OCAML-PRIM-OPS

    rule
        <k> initEnv => assigning ...</k>
        <assign> . =>
            IdLid("~-") |-> primNegate
            IdLid("raise") |-> primRaise
            IdLid("+") |-> primAdd
            IdLid("-") |-> primSubtract
            IdLid("*") |-> primMultiply
            IdLid("/") |-> primDivide

            IdLid("not") |-> primNot
            IdLid("&&") |-> primAnd
            IdLid("||") |-> primOr
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

module OCAML-TOP-LEVEL is
    //@ Top-level phrases in an OCaml module (also known as structure items?)
    including OCAML-INCLUDE

    rule
        <k> StExp(Exp:K) => Exp ...</k>

end module

module OCAML-PATTERNS is
    including OCAML-INCLUDE

    syntax K
      ::= "bind-failure"
        | "bind-success" "(" Map ")"

    rule
        <pattern> PaInt(I) => . ...</pattern>
        <value> I:Int => . ...</value>

    rule // x (variable)
        <pattern> PaId(LId:LId) => . ...</pattern>
        <value> K:K => . ...</value>
        <subst>... . => LId |-> K ...</subst>

    rule // _ (wildcard)
        <pattern> PaAny => . ...</pattern>
        <value> K:K => . ...</value>

    rule // p as x (alias)
        <pattern> PaAli(Pat:K, PaId(X:Id)) => Pat ...</pattern>
        <value> K:K ...</value>
        <subst>... . => X |-> K ...</subst>

    rule // p : t (type constraint)
        <pattern> PaTyc(Pat:K, _) => Pat ...</pattern>
        <value> K:K ...</value>

    rule
        <pattern> PaTup(Pat:K) => Pat ...</pattern>
        <value> ExTup(K:K) => K ...</value>

    rule
        <pattern> PaCom(Pat1:K, Pat2:K) => Pat1 ~> Pat2 ...</pattern>
        <value> ExCom(K1:K, K2:K) => K1 ~> K2 ...</value>

    rule
        <value> cons(K:K) => K ...</value>

    rule
        <pattern> PaId(UId:UId) => . ...</pattern>
        <value> UId => . ...</value>

    rule
        <pattern> PaApp(Pat1:K, Pat2:K) => Pat1 ~> Pat2 ...</pattern>
        <value> ExApp(K1:K, K2:K) => K1 ~> K2 ...</value>

    rule // p | p (or-patterns)
        <bindAttempt>...
            <pattern> PaOrp(Pat1:K, Pat2:K) ~> Pats:K </pattern>
            <value> V:K </value>
            <subst> Subst:Map </subst>
        ...</bindAttempt>
        => (
            <bindAttempt>...
                <pattern> Pat1 ~> Pats </pattern>
                <value> V </value>
                <subst> Subst </subst>
            ...</bindAttempt>
            <bindAttempt>...
                <pattern> Pat2 ~> Pats </pattern>
                <value> V </value>
                <subst> Subst </subst>
            ...</bindAttempt>
            )

    rule
        <bindK> binding => bind-success(Subst) </bindK>
        (
            <bindAttempt>...
                <value> . </value>
                <pattern> . </pattern>
                <subst> Subst:Map </subst>
            ...</bindAttempt>
            => .
        )

    rule
        <patternAnalysis>...
            <bindAttempt>...
                <value> V:K ...</value>
                <pattern> Pat:K ...</pattern>
            ...</bindAttempt>
            => .
        ...</patternAnalysis>
        when notBool (matches V Pat)

    rule
        <bindK> binding => bind-failure </bindK>
        <bindAttempts> .Bag </bindAttempts>

    // GC
    rule
        <patternAnalysis>...
            <bindK> .K </bindK>
        ...</patternAnalysis>
        => .Bag

    /*@ Unfortunately, we have to define the predicate below since we don't
    have a way of saying "when no other rule matches" */
    op matches__ : K K -> Bool
    eq matches _ PaId(LId:LId) = true
    eq matches UId:UId PaId(UId) = true
    eq matches cons(_) _ = true
    eq matches _ PaAny = true
    eq matches _ PaAli(_, _) = true
    eq matches _ PaTyc(_, _) = true
    eq matches ExTup(_) PaTup(_) = true
    eq matches ExCom(_, _) PaCom(_, _) = true
    eq matches I:Int PaInt(I) = true
    eq matches . . = true
    eq matches _ _ = false [owise]

end module

module OCAML-MATCHING is
    including OCAML-INCLUDE
    including OCAML-PATTERNS

    syntax K
      ::= "match-failure"
        | "match-success" "(" K "," Map ")"

    rule
        <cases> McOr(MC1:K, MC2:K) => MC1 ~> MC2 ...</cases>

    rule
        <matchK> matching => binding </matchK>
        <cases> McArr(Pat:K, _, Exp:K) => . ...</cases>
        <scrutinee> V:K </scrutinee>
        <expr> _ => Exp </expr>
        ( . =>
            <patternAnalysis>...
                <bindAttempts>
                    <bindAttempt>...
                        <value> V </value>
                        <pattern> Pat </pattern>
                    ...</bindAttempt>
                </bindAttempts>
            ...</patternAnalysis>
        )

    rule
        <matchK> binding => matching </matchK>
        <bindK> bind-failure => . </bindK>

    rule
        <matchK> binding => match-success(Exp, Subst) </matchK>
        <bindK> bind-success(Subst:Map) => . </bindK>
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

module OCAML-MUTABLES is
    including OCAML-INCLUDE

    rule
        <k> 'primRef(V:KResult) => . ...</k>
        <store>... . => loc(N) |-> V ...</store>
        <nextLoc> N:Int => N +Int 1 </nextLoc>

    rule
        <k> ExAss(L:Loc, V:KResult) => 'primAssign(L,, V) ...</k>

    rule
        <k> 'primAssign(L:Loc,, V:KResult) => . ...</k>
        <store>... L |-> (_ => V) ...</store>

    rule
        <k> ExAcc(L:Loc, IdLid("val")) => V ...</k>
        <store>... L |-> V ...</store>

end module

module OCAML-EXCEPTIONS is
    including OCAML-INCLUDE

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

module OCAML-EXPRESSIONS is
    including OCAML-INCLUDE
    including OCAML-PRIM-OPS
    including OCAML-MATCHING

    rule
        <k> ExInt(I:Int) => I ...</k>

    rule
        <k> ExId(LId:LId) => K ...</k>
        <env>... LId |-> L:Loc ...</env>
        <store>... L |-> K:K ...</store>

    rule
        <k> ExId(UId:UId) => UId ...</k>

    rule
        <k> ExApp(UId:UId, V:KResult) => cons(ExApp(UId, V)) ...</k>

    rule
        <k> ExApp(cons(K:K), V:KResult) => cons(ExApp(K, V)) ...</k>

    syntax KResult ::= "closure" "(" Map "," K ")"

    rule
        <k> ExFun(MC:K) => closure(Env, MC) ...</k>
        <env> Env:Map </env>

    context ExApp(closure(_, _), HOLE)

    rule
        <k> ExApp(closure(Env':Map, MC:K), V:KResult) => ExMat(V, MC) ~> env(Env) ...</k>
        <env> Env => Env' </env>

    rule
        <k> ExSeq(K:K) => K ...</k>

    rule
        <k> ExSem(V:KResult, Exp:K) => Exp ...</k>

    rule ExIfe(true, Exp:K, _) => Exp
    rule ExIfe(false, _, Exp:K) => Exp

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

    rule
        <k> ExMat(V:KResult, MC:K) => matching ...</k>
        (. =>
            <matchAnalysis>...
                <cases> MC </cases>
                <scrutinee> V </scrutinee>
            ...</matchAnalysis>
        )

    // TODO env recovery
    rule
        <k> matching => assigning ~> K ~> env(Env) ...</k>
        <env> Env:Map </env>
        <assign> . => Subst </assign>
        <matchK> match-success(K:K, Subst:Map) => . </matchK>

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


module OCAML-SEMANTICS is
    including OCAML-INCLUDE

    including OCAML-PRIM-OPS
    including OCAML-INIT
    including OCAML-CLEANUP
    including OCAML-TOP-LEVEL
    including OCAML-PATTERNS
    including OCAML-MATCHING
    including OCAML-EXCEPTIONS
    including OCAML-MUTABLES
    including OCAML-EXPRESSIONS
    including OCAML-HELPERS

end module
