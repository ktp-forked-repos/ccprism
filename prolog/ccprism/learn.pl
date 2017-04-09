:- module(ccp_learn, [ converge/5, learn/4, learn/5 ]).

/** <module> Expectation-maximisation, variational Bayes and deterministic annealling
*/

:- use_module(library(math),       [sub/3]).
:- use_module(library(callutils),  [(*)/4, true2/2]).
:- use_module(library(plrand),     [mean_log_dirichlet/2, log_partition_dirichlet/2]).
:- use_module(lazymath, [max/3, add/3, mul/3, pow/3, stoch/2, map_sum/4, patient/3]).
:- use_module(graph,    [graph_counts/5]).
:- use_module(switches, [ map_sw/3, map_swc/3, map_swc/4, map_sum_sw/3, map_sum_sw/4
                        , sw_log_prob/3, sw_posteriors/3]).

learn(Method,Stats,Graph,Step) :- learn(Method,Stats,1,Graph,Step).

learn(ml, Stats, ITemp, Graph, ccprism:unify3(t(P1,P2,LL))) :-
   graph_counts(Stats, lin, Graph, PP, LL-Eta),
   map_swc(pow(ITemp), P1, PP),
   map_sw(stoch, Eta, P2).

learn(map(Prior), Stats, ITemp, Graph, ccprism:unify3(t(P1,P2,LL+LP))) :-
   graph_counts(Stats, lin, Graph, PP, LL-Eta),
   patient(mul(ITemp)*sw_log_prob(Prior), P1, LP),
   sw_posteriors(Prior, Eta, Post),
   map_swc(pow(ITemp), P1, PP),
   map_sw(stoch*maplist(max(0)*add(-1)), Post, P2).

learn(vb(Prior), Stats, ITemp, Graph, ccprism:unify3(t(A1,A2,LL-Div))) :-
   maplist(map_swc(true2,Prior), [A1,Pi]), % establish same shape as prior
   map_swc(mul_add(ITemp,1-ITemp), Prior, EffPrior),
   map_sum_sw(log_partition_dirichlet, Prior, LogZPrior),
   patient(vb_helper(ITemp, LogZPrior, EffPrior), A1, Pi - Div),
   graph_counts(Stats, log, Graph, Pi, LL-Eta),
   map_swc(mul_add(ITemp), EffPrior, Eta, A2).

vb_helper(ITemp, LogZPrior, EffPrior, A, Pi - Div) :- 
   map_sw(mean_log_dirichlet, A, PsiA),
   map_swc(sub, EffPrior, A, Delta),
   map_swc(mul(ITemp), PsiA, Pi),
   map_sum_sw(log_partition_dirichlet, A, LogZA),
   map_sum_sw(map_sum(math:mul), PsiA, Delta, Diff),
   Div is Diff - LogZA + ITemp*LogZPrior.

mul_add(1,X,Y,Z) :- !, when(ground(Y), Z is X+Y).
mul_add(K,X,Y,Z) :- when(ground(Y), Z is X+K*Y).
unify3(PStats,LP,P1,P2) :- copy_term(PStats, t(P1,P2,LP)).

% --- convergence ---
:- meta_predicate converge(+,1,-,+,-).
converge(Test, Setup, [X0|History], S0, SFinal) :-
   call(Setup, Step),
   call(Step, X0, S0, S1),
   converge_x(Test, Step, X0, History, S1, SFinal).
converge_x(Test, Step, X0, [X1|History], S1, SFinal) :-
   call(Step, X1, S1, S2),
   (  converged(Test, X0, X1) -> History=[], SFinal=S2
   ;  converge_x(Test, Step, X1, History, S2, SFinal)
   ).

converged(abs(Eps), X1, X2) :- abs(X1-X2) =< Eps.
converged(rel(Del), X1, X2) :- abs((X1-X2)/(X1+X2)) =< Del.
