:- use_module(library(plrand)).
:- use_module(library(listutils), [zip/3, drop/3]).
:- use_module(library(ccprism/handlers)).
:- use_module(library(ccprism/learn)).
:- use_module(library(ccprism/effects)).
:- use_module(library(ccprism)).
:- use_module(library(julia)).
:- use_module(dice).
:- use_module(tools).

:- initialization(init, program).

init :-
   persistent_history,
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
   length(Xs,N), maplist(dice(K),Xs),
   histogram(Xs, Hist), !savefig(Hist, "hist.pdf"),
   goal_graph(maplist(dice(K),Xs), G),
   maplist(call(Learner, G), Curves).

learn1(Modifier, Drop, Tol, Meth, G, H) :-
   graph_params(random, G, P0),
   converge(abs(Tol), call(Modifier, learn(ml, io(Meth), G)), HFull, P0, _P1),
   drop(Drop, HFull, H).

add_plot(Drop, Y, P1, P2) :-
   length(Y, NumIts),
   numlist(1, NumIts, X),
   P2 ?? 'plot!'(P1, Drop+X, Y).

with_plot(Setup, with_plot(Step)) :- call(Setup, Step).
with_plot(Step, Cost, S1, S2) :-
   call(Step, Cost, S1, S2),
   member((dice:die)-Probs, S2),
   format(string(Title), "~1f", [Cost]),
   !gui(1, bar(Probs, title=Title, size= #(160, 160), ylim= #(0,0.6))).

run(Mod,Drop,Tol,K,N,T) :-
   length(Curves,T),
   with_brs(rs, with_die_sampler(multitrial(learn1(Mod, Drop, Tol, log), K, N, Curves))),
   format(string(Title), "dice: K=~w, N=~w, tol=~g", [K,N,Tol]),
   P0 = plot(grid=true, title=Title, xlabel="iteration", ylabel="log likelihood"),
   foldl(add_plot(Drop), Curves, P0, PP),
   !savefig(PP, "test2.pdf").
