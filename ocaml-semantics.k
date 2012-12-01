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

    syntax KResult ::= "cons" "(" K "," List{K} ")"

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
            <records>
                <record multiplicity="*">
                    <recordId> 0 </recordId>
                    <fields> .Map </fields>
                </record>
            </records>
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
            <output> "" </output>
        </T>
        <result multiplicity="?" color="DodgerBlue">
            <exprResult> .K </exprResult>
            <output> "" </output>
        </result>


end module

module OCAML-APPLICATION is
    including OCAML-SYNTAX

    syntax K ::= "apply" "(" K "," List{K} ")" [strict(1)]
    syntax K ::= "flattenApp" "(" K "," List{K} ")"

    rule ExApp(K1:K, K2:K) => flattenApp(ExApp(K1, K2), .List{K})

    define flattenApp(ExApp(K:K, Arg:K), Args:List{K}) => flattenApp(K, Arg,, Args)
    define flattenApp(PaApp(K:K, Arg:K), Args:List{K}) => flattenApp(K, Arg,, Args)
    define flattenApp(K:K, Args:List{K}) => apply(K, Args)
        when getKLabel(K) =/=KLabel 'ExApp`(_`,_`) orBool getKLabel(K) =/=KLabel 'PaApp`(_`,_`)

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

module OCAML-UNIT is
    including OCAML-INCLUDE

    syntax KResult ::= "unit"
    rule IdUid("()") => unit

end module

module OCAML-ARITHMETIC is
    including OCAML-INCLUDE

    rule ExInt(I:Int) => I

    syntax External
      ::= "%addint"
        | "%subint"
        | "%mulint"
        | "%divint"
        | "%modint"
        | "%negint"

    rule '%addint(I1:Int,, I2:Int) => I1 +Int I2
    rule '%subint(I1:Int,, I2:Int) => I1 -Int I2
    rule '%mulint(I1:Int,, I2:Int) => I1 *Int I2
    rule '%divint(I1:Int,, I2:Int) => I1 /Int I2
    rule '%modint(I1:Int,, I2:Int) => I1 %Int I2
    rule '%negint(I:Int) => 0 -Int I

end module

module OCAML-BOOLEANS is
    including OCAML-INCLUDE

    rule IdUid("False") => false
    rule IdUid("True") => true

    syntax External ::= "%boolnot"

    rule '%boolnot(false) => true
    rule '%boolnot(true) => false

    syntax LazyExternal ::= "%sequand" | "%sequor"

    rule '%sequand(Exp1:K,, Exp2:K) => ExIfe(Exp1, Exp2, false)
    rule '%sequor(Exp1:K,, Exp2:K) => ExIfe(Exp1, true, Exp2)

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

    context apply(UId:UId, _:List{K},, HOLE,, _:List{K}) [superheat]

    rule apply(UId:UId, VS:List{KResult}) => cons(UId, VS)

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

    syntax External ::= "%raise"

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
        <k> '%raise(V:KResult) ~> _ => ExMat(V, McOr(MC, McArr(PaAny, ExNil, 'primRaise(V)))) ~> K </k>
        <xstack> x(K:K, MC:K, Env:Map) => . ...</xstack>
        <env> _ => Env </env>

end module

module OCAML-RECORDS is
    including OCAML-INCLUDE
    including OCAML-UNIT

    syntax KResult ::= "recordEntry" "(" Int ")"

    rule
        <k> ExRec(K:K, _) => recordEntry(N) ...</k>
        <nextLoc> N:Int => N +Int 1 </nextLoc>
        ( . =>
            <record>...
                <recordId> N </recordId>
                <fields> getFields(K) </fields>
            ...</record>
        )

    syntax Map ::= "getFields" "(" K ")"
    define getFields(RbSem(R1:K, R2:K)) => getFields(R1) getFields(R2)
    define getFields(RbEq(Id:Id, K:K)) => Id |-> K

    rule
        <k> ExAcc(recordEntry(N:Int), ExId(X:Id)) => V ...</k>
        <recordId> N </recordId>
        <fields>... X |-> V:KResult ...</fields>

    context ExAss(ExAcc(HOLE, _), _)

    rule
        <k> ExAss(ExAcc(recordEntry(N:Int), ExId(X:Id)), V:KResult) => unit ...</k>
        <recordId> N </recordId>
        <fields>... X |-> (_ => V) ...</fields>
        [supercool]

end module

module OCAML-REF is
    including OCAML-INCLUDE

    syntax External ::= "%ref" // %makemutable

    rule
        <k> '%ref(V:KResult) => ExRec(RbEq(IdLid("val"), V), ExNil) ...</k>

end module

module OCAML-IO is
    including OCAML-INCLUDE
    including OCAML-UNIT

    syntax External
      ::= "%print-int"

    rule
        <k> '%print-int(I:Int) => unit ...</k>
        <output> S:String => S +String Int2String(I) </output>
        [supercool]

end module

module OCAML-PATTERNS is
    including OCAML-INCLUDE
    including OCAML-UNIT

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
        <patterns>... PaId(UId:UId) <- UId => . ...</patterns>

    rule
        <patterns>... PaId(IdUid("()")) <- unit => . ...</patterns>

    rule
        <patterns>... PaTup(Pat:K) <- ExTup(Exp:K) => Pat <- Exp ...</patterns>

    rule
        <patterns>...
            PaCom(Pat1:K, Pat2:K) <- ExCom(Exp1:K, Exp2:K) =>
                (Pat1 <- Exp1)
                (Pat2 <- Exp2)
        ...</patterns>

    rule
        <patterns>...
            (PaApp(Pat1:K, Pat2:K) => flattenApp(PaApp(Pat1, Pat2), .List{K})) <- _
        ...</patterns>

    rule
        <patterns>...
            apply(Pat:K, Pats:List{K}) <- cons(UId:UId, Args:List{K})
            => (Pat <- UId) zip<-(Pats, Args)
        ...</patterns>

    syntax Bag ::= "zip<-" "(" List{K} "," List{K} ")"
    define zip<-(Pat,, Pats, Arg:K,, Args) => (Pat <- Arg) zip<-(Pats, Args)
    define zip<-(.List{K}, .List{K}) => .

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
    eq matches unit PaId(IdUid("()")) = true
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
    including OCAML-REF
    including OCAML-EXCEPTIONS
    including OCAML-IO

    // TODO eventually this will go in a separate Pervasives module
    rule
        <k> initEnv => assigning ...</k>
        <assign> . =>
            IdLid("+") |-> external(%addint, 2)
            IdLid("-") |-> external(%subint, 2)
            IdLid("*") |-> external(%mulint, 2)
            IdLid("/") |-> external(%divint, 2)
            IdLid("mod") |-> external(%modint, 2)
            IdLid("~-") |-> external(%negint, 1)

            IdLid("not") |-> external(%boolnot, 1)
            IdLid("&&") |-> external(%sequand, 2)
            IdLid("||") |-> external(%sequor, 2)

            IdLid("raise") |-> external(%raise, 1)

            IdLid("ref") |-> external(%ref, 1)

            IdLid("print_int") |-> external(%print-int, 1)
        </assign>

end module

module OCAML-CLEANUP is
    including OCAML-INCLUDE

    rule
        <T>...
            <k> V:KResult </k>
            <output> S:String </output>
        ...</T>
        =>
        <result>...
            <exprResult> V </exprResult>
            <output> S </output>
        ...</result>

end module

module OCAML-SEMANTICS is
    including OCAML-INCLUDE

    including OCAML-UNIT
    including OCAML-ARITHMETIC
    including OCAML-BOOLEANS
    including OCAML-CONTROL-FLOW
    including OCAML-LET-LETREC
    including OCAML-FUNCTIONS
    including OCAML-EXCEPTIONS
    including OCAML-RECORDS
    including OCAML-REF
    including OCAML-IO
    including OCAML-PATTERNS
    including OCAML-MATCHING

    including OCAML-TOP-LEVEL

    including OCAML-HELPERS
    including OCAML-INIT
    including OCAML-CLEANUP

end module
