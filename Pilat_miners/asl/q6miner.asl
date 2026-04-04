// Q6 Miner Agent — shared logic for q6m1..q6m6
//
// Strategy: 6-Quadrant
//   - Each miner owns one of six quadrants (3 columns x 2 rows).
//   - Phase 1 (first 15 % of steps): pure exploration — record gold,
//     do NOT fetch.  After Phase 1 the miner reports its quadrant summary
//     to q6leader (lot-of-gold / quadrant-explored messages).
//   - Phase 2 (remaining steps): mine using gathered knowledge + live
//     perception.
//
// Local-search rule:
//   When a NEW gold is spotted (outside exploration phase) and we have not yet
//   searched around that exact cell, the miner first visits every unvisited
//   cell in the 3x3 grid around the gold (within the quadrant boundaries),
//   recording any additional gold found.  It then runs normal choose_goal to
//   collect as much gold as capacity allows before heading to the depot.

{ include("moving.asl") }
{ include("search_quadrant.asl") }
{ include("fetch_gold.asl") }
{ include("goto_depot.asl") }
{ include("q6_allocation_protocol.asl") }

{ register_function("carrying.gold", 0, "carrying_gold") }
{ register_function("jia.path_length", 4, "jia.path_length") }

/* ── Initial beliefs ────────────────────────────────────────────────── */

free.
my_capacity(3).
lot_of_gold_threshold(3).
low_gold_threshold(2).
search_gold_strategy(quadrant).

/* ── Rules ──────────────────────────────────────────────────────────── */

in_explore_phase :-
    pos(_,_,Step) & steps(_,Total) & 15 * Step < Total.

quadrant_gold_count(Count) :-
    quadrant(X1,Y1,X2,Y2) &
    .findall(g, (gold(X,Y) & X >= X1 & X =< X2 & Y >= Y1 & Y =< Y2), L) &
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

check_commit(_, 0, in_my_place)   :- true.
check_commit(G, _, not_committed) :- not committed_to(G,_,_).
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

// No quadrant assigned fallback
+!search_gold(quadrant) : not quadrant(_,_,_,_) & pos(X,Y,_) & jia.near_least_visited(X,Y,TX,TY)
  <- !pos(TX,TY);
     !!search_gold(quadrant).
+!search_gold(quadrant) : not quadrant(_,_,_,_)
  <- .wait(500); !!search_gold(quadrant).


/* ── Initialisation ─────────────────────────────────────────────────── */

+pos(_,_,0)
  <- ?gsize(S,_,_);
     .my_name(Me);
     .print(Me, " starting sim ", S);
     !q6_inform_gsize(S);
     !choose_goal.

// Only q6m1 bootstraps the leader with map/depot info.
+!q6_inform_gsize(S) : .my_name(q6m1)
  <- ?depot(S,DX,DY);
     .send(q6leader, tell, depot(S,DX,DY));
     ?gsize(S,W,H);
     .send(q6leader, tell, gsize(S,W,H)).
+!q6_inform_gsize(_).


/* ── Goal selection ─────────────────────────────────────────────────── */

@q6cg_explore[atomic]
+!choose_goal : in_explore_phase
  <- !change_to_search.

@q6cg_transition[atomic]
+!choose_goal : not in_explore_phase & not exploration_reported
  <- +exploration_reported;
     !q6_report_exploration;
     !choose_goal.

@q6cg_fetch[atomic]
+!choose_goal
  : container_has_space &
    .findall(gold(X,Y), gold(X,Y), LG) &
    evaluate_golds(LG, LD) &
    .length(LD) > 0 &
    .min(LD, d(_, NewG, _)) &
    worthwhile(NewG)
  <- !change_to_fetch(NewG).

+!choose_goal : carrying_gold(NG) & NG > 0
  <- !change_to_goto_depot.

+!choose_goal <- !change_to_search.


/* ── Exploration-phase report ───────────────────────────────────────── */

+!q6_report_exploration
  : quadrant(X1,Y1,X2,Y2) & quadrant_gold_count(Count) & .my_name(Me)
  <- .print(Me, ": exploration done — ", Count, " golds in quadrant.");
     .send(q6leader, tell, quadrant_explored(Me, X1, Y1, X2, Y2, Count));
     lot_of_gold_threshold(Thresh);
     if (Count >= Thresh & not reported_lot_of_gold) {
         +reported_lot_of_gold;
         .send(q6leader, tell, lot_of_gold_in_quadrant(Me, X1, Y1, X2, Y2))
     }.
+!q6_report_exploration.


/* ── Change-goal helpers ─────────────────────────────────────────────── */

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


/* ── Cell perception ─────────────────────────────────────────────────── */

// EXPLORE PHASE — just record gold, do not fetch yet.
@q6cell_explore[atomic]
+cell(X,Y,gold) : in_explore_phase & not gold(X,Y)
  <- +gold(X,Y);
     .send(q6leader, tell, gold(X,Y));
     .broadcast(tell, gold(X,Y));
     !q6_check_lot_of_gold.

// MINING PHASE — new gold, no local search done yet, not currently searching.
// Trigger 3x3 local search around this gold before choosing a fetch goal.
@q6cell_mine_new[atomic]
+cell(X,Y,gold)
  : not in_explore_phase & container_has_space & not gold(X,Y) &
    not local_searching & not done_local_search(X,Y)
  <- +gold(X,Y);
     +done_local_search(X,Y);
     .send(q6leader, tell, gold(X,Y));
     .broadcast(tell, gold(X,Y));
     !q6_check_lot_of_gold;
     -free;
     !!q6_local_search_then_choose(X,Y).

// MINING PHASE — new gold but local search already done for this cell,
// or we are currently inside a local search pass (just record it).
@q6cell_mine_known[atomic]
+cell(X,Y,gold) : not in_explore_phase & container_has_space & not gold(X,Y)
  <- +gold(X,Y);
     .send(q6leader, tell, gold(X,Y));
     .broadcast(tell, gold(X,Y));
     !q6_check_lot_of_gold;
     if (not local_searching) { !choose_goal }.

// Full — just remember for later.
+cell(X,Y,gold) : not container_has_space & not gold(X,Y)
  <- +gold(X,Y);
     +announced(gold(X,Y));
     .send(q6leader, tell, gold(X,Y));
     .broadcast(tell, gold(X,Y)).

// Gold disappeared (someone else picked it).
+cell(X,Y,empty) : gold(X,Y) & not .desire(fetch_gold(gold(X,Y)))
  <- !remove(gold(X,Y));
     .send(q6leader, tell, picked(gold(X,Y)));
     .broadcast(tell, picked(gold(X,Y))).


/* ── Local 3x3 search ────────────────────────────────────────────────── */
//
// Visit all 8 neighbours of the spotted gold cell that are:
//   • inside our assigned quadrant
//   • not an obstacle
//   • not already visited in a local-search pass this session
// Any gold found during the visit is handled by the cell handlers above
// (recorded in beliefs, but choose_goal is suppressed by local_searching flag).
// After visiting all candidates, restore free and run choose_goal normally.

+!q6_local_search_then_choose(GX, GY)
  : quadrant(QX1, QY1, QX2, QY2)
  <- +local_searching;
     XL = GX - 1; XR = GX + 1; YU = GY - 1; YD = GY + 1;
     !q6_try_cell(XL, YU, QX1, QY1, QX2, QY2);
     !q6_try_cell(GX, YU, QX1, QY1, QX2, QY2);
     !q6_try_cell(XR, YU, QX1, QY1, QX2, QY2);
     !q6_try_cell(XL, GY, QX1, QY1, QX2, QY2);
     !q6_try_cell(XR, GY, QX1, QY1, QX2, QY2);
     !q6_try_cell(XL, YD, QX1, QY1, QX2, QY2);
     !q6_try_cell(GX, YD, QX1, QY1, QX2, QY2);
     !q6_try_cell(XR, YD, QX1, QY1, QX2, QY2);
     -local_searching;
     +free;
     !!choose_goal.
// No quadrant assigned — still finish gracefully.
+!q6_local_search_then_choose(_, _)
  <- -local_searching;
     +free;
     !!choose_goal.
-!q6_local_search_then_choose(_, _)
  <- -local_searching;
     +free;
     !!choose_goal.

// Visit one candidate cell.
+!q6_try_cell(X, Y, QX1, QY1, QX2, QY2)
  : container_has_space &
    X >= QX1 & X =< QX2 & Y >= QY1 & Y =< QY2 &
    not jia.obstacle(X,Y) & not local_cell_visited(X,Y)
  <- +local_cell_visited(X,Y);
     !pos(X,Y).
+!q6_try_cell(_, _, _, _, _, _).        // skip: out of bounds / obstacle / visited / full
-!q6_try_cell(_, _, _, _, _, _).        // skip: unreachable


/* ── Lot-of-gold check ───────────────────────────────────────────────── */

+!q6_check_lot_of_gold
  : not reported_lot_of_gold &
    quadrant_gold_count(Count) &
    lot_of_gold_threshold(Thresh) & Count >= Thresh &
    quadrant(X1,Y1,X2,Y2) & .my_name(Me)
  <- .print(Me, ": LOT OF GOLD (", Count, ") — alerting q6leader.");
     +reported_lot_of_gold;
     .send(q6leader, tell, lot_of_gold_in_quadrant(Me, X1, Y1, X2, Y2)).
+!q6_check_lot_of_gold.


/* ── Leader-issued redirection ───────────────────────────────────────── */

@q6redir[atomic]
+mine_in_quadrant(X1,Y1,X2,Y2)[source(q6leader)]
  <- .my_name(Me);
     .print(Me, " redirected to (", X1,",",Y1,")-(", X2,",",Y2,")");
     -exploration_reported;
     -reported_lot_of_gold;
     -local_searching;
     .drop_all_desires;
     +free;
     -+quadrant(X1,Y1,X2,Y2).


/* ── Belief-removal helper ───────────────────────────────────────────── */

+!remove(gold(X,Y))
  <- .abolish(gold(X,Y));
     .abolish(committed_to(gold(X,Y),_,_));
     .abolish(picked(gold(X,Y)));
     .abolish(announced(gold(X,Y)));
     .abolish(allocated(gold(X,Y),_)).


/* ── End of simulation ───────────────────────────────────────────────── */

+end_of_simulation(S,R)
  <- .drop_all_desires;
     !remove(gold(_,_));
     .abolish(picked(_));
     .abolish(exploration_reported);
     .abolish(reported_lot_of_gold);
     .abolish(local_searching);
     .abolish(done_local_search(_,_));
     .abolish(local_cell_visited(_,_));
     -+search_gold_strategy(quadrant);
     .abolish(quadrant(_,_,_,_));
     .abolish(last_checked(_,_));
     -+free;
     .print("Q6Miner -- END ", S, ": ", R).

@q6restart[atomic]
+restart
  <- .abolish(exploration_reported);
     .abolish(reported_lot_of_gold);
     .abolish(local_searching);
     .drop_all_desires;
     !choose_goal.
