:- module(ccp_switches, [ map_sw/3, map_swc/3, map_sum_sw/3, map_sum_sw/4, map_swc/4
                        , sw_expectations/2, sw_log_prob/3, sw_posteriors/3, marg_log_prob/3
                        , dirichlet/2
                        ]).

/** <module> Tools for working with lists of switch parameters */

:- use_module(library(callutils),   [(*)/4]).
:- use_module(library(data/pair),   [fsnd/3, snd/2]).
:- use_module(library(plrand),      [log_prob_dirichlet/3, log_partition_dirichlet/2]).
:- use_module(library(prob/strand), [pure//2]).
:- use_module(library(prob/tagged), [dirichlet//2]).
:- use_module(effects,  [sample/2]).
:- use_module(lazymath, [add/3, stoch/2, map_sum/3, map_sum/4]). 

fsnd3(P,A-X,A-Y,A-Z) :- call(P,X,Y,Z).
user:goal_expansion(fsnd3(P,SX,SY,SZ),(SX=S-X, SY=S-Y, SZ=S-Z, call(P,X,Y,Z))).

dirichlet(As,Ps) :- sample(pure(dirichlet(As)),Ps).

% manipulating parameter lists
map_sw(P,X,Y) :- maplist(fsnd(P),X,Y).
map_swc(P,X,Y) :- map_sw(maplist(P),X,Y).
map_swc(P,X,Y,Z) :- maplist(fsnd3(maplist(P)),X,Y,Z).
map_sum_sw(P,X,Sum) :- map_sum(P*snd,X,Sum).
map_sum_sw(P,X,Y,Sum) :- map_sum(f2sw1(P),X,Y,Sum).
f2sw1(P,SW-X,SW-Y,Z) :- call(P,X,Y,Z).

sw_posteriors(Prior,Eta,Post) :- map_swc(add,Eta,Prior,Post).
sw_expectations(Alphas,Probs) :- map_sw(stoch,Alphas,Probs).
sw_samples(Alphas,Probs)      :- map_sw(dirichlet,Alphas,Probs).
sw_log_prob(Alphas,Probs,LP)  :- map_sum_sw(log_prob_dirichlet,Alphas,Probs,LP).
sw_marg_log_prob(Prior,Eta,LP):- map_sum_sw(marg_log_prob,Prior,Eta,LP).

marg_log_prob(Prior,Eta,LP) :-
   maplist(add,Prior,Eta,Post),
   maplist(log_partition_dirichlet,[Prior,Post],[Bot,Top]),
   LP is Top - Bot.
