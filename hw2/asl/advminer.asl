// Advanced Quadrant Miner Agent (ported from quadrant_miner.asl in gold-miners-II)
//
// Four instances: adv1 (top-left), adv2 (top-right),
//                 adv3 (bottom-left), adv4 (bottom-right).
//
// Phase 1 — first 10% of steps: pure exploration of assigned quadrant.
//   Gold positions are recorded and forwarded to advleader, but NOT fetched.
//
// Phase 2 — remaining 90%: mine gold using knowledge gathered in Phase 1.
//
// At end of Phase 1 the miner reports its quadrant summary to advleader:
//   - "lot_of_gold_in_quadrant" if >= 3 golds found
//   - "quadrant_explored" always

{ include("moving.asl") }
{ include("search_quadrant.asl") }
{ include("search_unvisited.asl") }
{ include("fetch_gold.asl") }
{ include("goto_depot.asl") }
{ include("adv_allocation_protocol.asl") }

{ register_function("carrying.gold", 0, "carrying_gold") }
{ register_function("jia.path_length", 4, "jia.path_length") }

/* -- Initial beliefs -- */

free.
my_capacity(3).
lot_of_gold_threshold(3).
low_gold_threshold(2).
search_gold_strategy(quadrant).

/* -- Rules -- */

in_explore_phase :-
    pos(_,_,Step) & steps(_,Total) & 10 * Step < Total.

quadrant_gold_count(Count) :-
    quadrant(X1,Y1,X2,Y2) &
    .findall(g(X,Y),
             (gold(X,Y) & X >= X1 & X =< X2 & Y >= Y1 & Y =< Y2),
             L) &
    .length(L, Count).

evaluate_golds([], []) :- true.
evaluate_golds([gold(GX,GY)|R], [d(U,gold(GX,GY),Annot)|RD]) :-
    evaluate_gold(gold(GX,GY), U, Annot) & evaluate_golds(R, RD).
evaluate_golds([_|R], RD) :- evaluate_golds(R, RD).

evaluate_gold(gold(X,Y), Utility, Annot) :-
    pos(AgX,AgY,_) &
    jia.path_length(AgX,AgY,X,Y,D) &
    jia.add_fatigue(D, Utility) &
    check_commit(gold(X,Y), Utility, Annot).

check_commit(_,  0, in_my_place)   :- true.
check_commit(G,  _, not_committed) :- not committed_to(G,_,_).
check_commit(gold(X,Y), MyD, committed_by(Ag,at(OtX,OtY),far(OtD))) :-
    committed_to(gold(X,Y),_,Ag) &
    jia.ag_pos(Ag,OtX,OtY) &
    jia.path_length(OtX,OtY,X,Y,OtD) &
    MyD < OtD.

worthwhile(gold(_,_)) :- carrying_gold(0).
worthwhile(gold(GX,GY)) :-
    carrying_gold(NG) & NG > 0 &
    pos(AgX,AgY,Step) & depot(_,DX,DY) & steps(_,Total) &
    Avail = Total - Step &
    jia.add_fatigue(jia.path_length(AgX,AgY,GX,GY), NG,   CN4) &
    jia.add_fatigue(jia.path_length(GX,GY,DX,DY),   NG+1, CN5) &
    Avail > (CN4 + CN5) * 1.1.


/* -- Initialisation -- */

+pos(_,_,0)
  <- ?gsize(S,_,_);
     .my_name(Me);
     .print(Me, " starting simulation ", S);
     !adv_inform_gsize_to_leader(S);
     !choose_goal.

+!adv_inform_gsize_to_leader(S) : .my_name(adv1)
  <- ?depot(S,DX,DY);
     .send(advleader,tell,depot(S,DX,DY));
     ?gsize(S,W,H);
     .send(advleader,tell,gsize(S,W,H)).
+!adv_inform_gsize_to_leader(_).


/* -- Goal selection -- */

@advcg_explore[atomic]
+!choose_goal : in_explore_phase
  <- .print("Exploration phase: scanning quadrant.");
     !change_to_search.

@advcg_transition[atomic]
+!choose_goal : not in_explore_phase & not exploration_reported
  <- +exploration_reported;
     !adv_report_exploration_summary;
     !choose_goal.

@advcg_fetch[atomic]
+!choose_goal
  : container_has_space &
    .findall(gold(X,Y), gold(X,Y), LG) &
    evaluate_golds(LG, LD) &
    .length(LD) > 0 &
    .min(LD, d(_, NewG, _)) &
    worthwhile(NewG)
  <- .print("Fetching ", NewG);
     !change_to_fetch(NewG).

+!choose_goal : carrying_gold(NG) & NG > 0
  <- !change_to_goto_depot.

+!choose_goal <- !change_to_search.


/* -- Exploration-phase report -- */

+!adv_report_exploration_summary
  : quadrant(X1,Y1,X2,Y2) & quadrant_gold_count(Count) & .my_name(Me)
  <- .print("Exploration done: found ", Count, " golds in quadrant.");
     .send(advleader, tell, quadrant_explored(Me, X1, Y1, X2, Y2, Count));
     if (not reported_lot_of_gold) {
         lot_of_gold_threshold(Thresh);
         if (Count >= Thresh) {
             .print("Reporting LOT OF GOLD to advleader (", Count, ").");
             +reported_lot_of_gold;
             .send(advleader, tell, lot_of_gold_in_quadrant(Me, X1, Y1, X2, Y2))
         }
     }.
+!adv_report_exploration_summary.


/* -- Change-goal helpers -- */

+!change_to_goto_depot : .desire(goto_depot).
+!change_to_goto_depot : .desire(fetch_gold(G))
  <- .drop_desire(fetch_gold(G)); !change_to_goto_depot.
+!change_to_goto_depot <- -free; !!goto_depot.

+!change_to_fetch(G) : .desire(fetch_gold(G)).
+!change_to_fetch(G) : .desire(goto_depot)
  <- .drop_desire(goto_depot); !change_to_fetch(G).
+!change_to_fetch(G) : .desire(fetch_gold(OG))
  <- .drop_desire(fetch_gold(OG)); !change_to_fetch(G).
+!change_to_fetch(G) <- -free; !!fetch_gold(G).

+!change_to_search : search_gold_strategy(S)
  <- -free; +free; .drop_all_desires; !!search_gold(S).


/* -- Gold / cell perception -- */

@advcell_explore[atomic]
+cell(X,Y,gold) : in_explore_phase & not gold(X,Y)
  <- .print("Gold noted during exploration: ", gold(X,Y));
     +gold(X,Y);
     .send(advleader, tell, gold(X,Y));
     .broadcast(tell, gold(X,Y));
     !adv_check_lot_of_gold.

@advcell_mine[atomic]
+cell(X,Y,gold) : container_has_space & not gold(X,Y)
  <- .print("Gold found: ", gold(X,Y));
     +gold(X,Y);
     .send(advleader, tell, gold(X,Y));
     .broadcast(tell, gold(X,Y));
     !adv_check_lot_of_gold;
     !choose_goal.

+cell(X,Y,gold) : not container_has_space & not gold(X,Y)
  <- +gold(X,Y);
     +announced(gold(X,Y));
     .send(advleader, tell, gold(X,Y));
     .broadcast(tell, gold(X,Y)).

+cell(X,Y,empty) : gold(X,Y) & not .desire(fetch_gold(gold(X,Y)))
  <- !remove(gold(X,Y));
     .send(advleader, tell, picked(gold(X,Y)));
     .broadcast(tell, picked(gold(X,Y))).


/* -- Lot-of-gold check -- */

+!adv_check_lot_of_gold
  : not reported_lot_of_gold &
    quadrant_gold_count(Count) &
    lot_of_gold_threshold(Thresh) &
    Count >= Thresh &
    quadrant(X1,Y1,X2,Y2) &
    .my_name(Me)
  <- .print("LOT OF GOLD in quadrant (", Count, "). Alerting advleader.");
     +reported_lot_of_gold;
     .send(advleader, tell, lot_of_gold_in_quadrant(Me, X1, Y1, X2, Y2)).
+!adv_check_lot_of_gold.


/* -- Leader-issued redirection -- */

@advredir_miner[atomic]
+mine_in_quadrant(X1,Y1,X2,Y2)[source(advleader)]
  <- .my_name(Me);
     .print(Me, " redirected to quadrant (", X1,",",Y1,")-(", X2,",",Y2,")");
     -exploration_reported;
     -reported_lot_of_gold;
     .drop_all_desires;
     +free;
     -+quadrant(X1,Y1,X2,Y2).


/* -- Belief-removal helper (named !remove so fetch_gold.asl can call it) -- */

+!remove(gold(X,Y))
  <- .abolish(gold(X,Y));
     .abolish(committed_to(gold(X,Y),_,_));
     .abolish(picked(gold(X,Y)));
     .abolish(announced(gold(X,Y)));
     .abolish(allocated(gold(X,Y),_)).


/* -- End of simulation -- */

+end_of_simulation(S,R)
  <- .drop_all_desires;
     !remove(gold(_,_));
     .abolish(picked(_));
     .abolish(exploration_reported);
     .abolish(reported_lot_of_gold);
     -+search_gold_strategy(quadrant);
     .abolish(quadrant(_,_,_,_));
     .abolish(last_checked(_,_));
     -+free;
     .print("AdvMiner -- END ", S, ": ", R).

@advmrl[atomic]
+restart
  <- .abolish(exploration_reported);
     .abolish(reported_lot_of_gold);
     .drop_all_desires;
     !choose_goal.
