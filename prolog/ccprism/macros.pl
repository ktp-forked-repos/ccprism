:- module(ccp_macros, [op(1150,fx,cctable)]).
/** <module> Term expansions to support tabling

This module implements a shallow program transformation to support
tabling. Predicates decalared `cctabled` are renamed (by a appending
a '#' to their given name) and the original predicate name defined as
a metacall of the renamed predicate via cctable/2, which is assumed 
to be available in the module where the tabled predicate is defined.

For example, to declare a tabled Fibonnaci sequence generator, do
==
:- cctable fib/2.
fib(0,1) :- !.
fib(1,1) :- !.
fib(N,X) :- 
   succ(N1,N), fib(N1,X1),
   succ(N2,N1),fib(N2,X2),
   X is X1+X2.
==
*/

:- op(1150,fx,cctable).

%% cctable(PredSpecfiers) is det
%  Declare predicates in PredSpecifiers (a comma separated list of Name/Arity
%  predicate specifier) as tabled.
user:term_expansion((:- cctable(Specs)), Clauses) :- 
   foldl_clist(expand_cctab, Specs, Clauses, []).

foldl_clist(P,(A,B)) --> !, call(P,A), foldl_clist(P,B).
foldl_clist(P,A) --> call(P,A).

expand_cctab(Name//Arity) --> !, 
   {A2 is Arity+2}, 
   expand_cctab(Name/A2).
expand_cctab(Name/Arity) --> 
   { functor(Head, Name, Arity), head_worker(Head, Worker)},
   [ (:- discontiguous('$cctabled'/1))
   , '$cctabled'(Head)
   , (Head :- cctabled(Head,Worker))
   ]. 

prolog:rename_predicate(M:Head, M:Worker) :-
   '$flushed_predicate'(M:'$cctabled'(_)),
   call(M:'$cctabled'(Head)), !,
   head_worker(Head, Worker).

head_worker(Head, Worker) :-
   Head   =.. [H|As], atom_concat(H,'#',W),
   Worker =.. [W|As].
