:- start_doc.
:- use_module(library(plrand)).
:- use_module(library(callops)).
:- use_module(library(listutils), [zip/3, drop/3]).
:- use_module(library(ccprism/handlers)).
:- use_module(library(ccprism/learn)).
:- use_module(library(ccprism/effects)).
:- use_module(library(ccprism/graph)).
:- use_module(library(ccprism)).
:- use_module(library(autodiff2)).
:- use_module(library(julia)).
:- use_module(library(plflow)).
:- use_module(library(clambda)).
:- use_module(dice).
:- use_module(tools).

:- initialization(init, program).

init :-
   persistent_history,
   confirm_on_halt,
   init_rnd_state(S), nb_setval(rs,S),
   init_julia.

init_julia :-
   !using('Plots'), !gr(),
   !default(show=false, size= #(300, 150)).


with_die_sampler(Goal) -->
   {make_lookup_sampler([(dice:die)-[0.2,0.4,0.1,0.3]], S)},
	run_sampling(S, Goal).

histogram(Xs, bar(Vals, Counts)) :-
   histof(Xs, Hist), zip(Vals, Counts, Hist).

multitrial(Learner, K, N, Curves) :-
   nmaplist(N,dice(K),Xs),
   goal_graph(maplist(dice(K),Xs), G),
   maplist(call(Learner, G), Curves).

learn1(Mode, Modifier, Drop, Tol, Meth, G, H) :-
   graph_params(random, G, P0),
   mode_learn_spec(Mode, G, Spec),
   converge(abs(Tol), learn(Spec, io(Meth), G) :> Modifier, HFull, P0, _P1),
   drop(Drop, HFull, H).

mode_learn_spec(ml, _, ml).
mode_learn_spec(map(A), G, map(Prior)) :- graph_params(A*uniform, G, Prior).
mode_learn_spec(vb(A),  G, vb(Prior))  :- graph_params(A*uniform, G, Prior).

add_plot(Drop, Y, P1, P2) :-
   length(Y, NumIts),
   numlist(1, NumIts, X),
   P2 ?? 'plot!'(P1, Drop+X, Y).

with_plot(Step, step_and_plot(Step)).
step_and_plot(Step, Cost, S1, S2) :-
   call(Step, Cost, S1, S2),
   member((dice:die)-Probs, S2),
   format(string(Title), "~1f", [Cost]),
   !gui(1, bar(Probs, title=Title, size= #(160, 160))). %, ylim= #(0,YMax))).

run_plot(Mod,Drop,Tol,K,N,T) :- run(ml,Mod,Drop,Tol,K,N,T).
run_plot(Mode,Mod,Drop,Tol,K,N,T) :-
   length(Curves,T),
   run(Mode,Mod,Drop,Tol,K,N,Curves),
   format(string(Title), "dice: K=~w, N=~w, tol=~g", [K,N,Tol]),
   P0 = plot(grid=true, title=Title, xlabel="iteration", ylabel="log likelihood"),
   foldl(add_plot(Drop), Curves, P0, PP),
   !savefig(PP, "curves.pdf").

run(Mode,Mod,Drop,Tol,K,N,Curves) :-
   with_brs(rs, with_die_sampler(multitrial(learn1(Mode, Mod, Drop, Tol, log), K, N, Curves))).

thingy(inside, G, P0, [TopVal], TopVal) :-
   graph_fold(r(autodiff2:log,autodiff2:lse,autodiff2:add_to_wsum,cons), P0, G, IG),
   expand_wsums, top_value(IG, TopVal).

thingy(io(ISc), G, P0, [LogProb|Outs], LogProb-Eta) :-
   graph_counts(io(ISc), lin, G, P0, Eta, LogProb),
   term_variables(Eta, Outs).

mode_graph_body(Mode, G, P0, Result, Body) :-
   time(thingy(Mode, G, P0, Outs, Result)),
   term_variables(P0, Ins),
   time(gather_ops(Ins, Outs, Ops)), length(Ops, NumOps),
   format('Compiled ~d ops.\n', [NumOps]),
   ops_body(Ins, Outs, Ops, Body).

speed_test(Mode,K,N,M) :-
   writeln('Timings are: search, build_chr, topsort, total_setup, iterations'),
   with_brs(rs, with_die_sampler(nmaplist(N, dice(K), Xs))),
   goal_graph(maplist(dice(K),Xs), G),
   graph_params(uniform, G, P0),
   time(mode_graph_body(Mode, G, P, Top, Body)),
   run_lambda_compiler((clambda(lambda([P,Top],Body), Pred), time(nmaplist(M, call(Pred, P0), _Vals)))).
