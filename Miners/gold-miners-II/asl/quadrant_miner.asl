// Quadrant Miner Agent
//
// Four instances: miner1 (top-left), miner2 (top-right),
//                 miner3 (bottom-left), miner4 (bottom-right).
//
// Phase 1 — first 10% of steps: pure exploration of the assigned quadrant.
//   Gold positions are recorded and forwarded to the leader, but NOT fetched.
//   Keeps the serpentine scan going without interruption.
//
// Phase 2 — remaining 90%: mine gold using knowledge gathered in Phase 1.
//
// At the end of Phase 1 the miner reports its quadrant summary to the leader:
//   - "lot_of_gold_in_quadrant" if >= 3 golds were found
//   - "quadrant_explored"       always, so the leader knows the final count
//
// The leader may react by:
//   - dispatching a scout to the rich quadrant, or
//   - redirecting this miner (mine_in_quadrant) to a richer quadrant.

{ include("moving.asl") }
{ include("search_quadrant.asl") }
{ include("search_unvisited.asl") }
{ include("fetch_gold.asl") }
{ include("goto_depot.asl") }
{ include("allocation_protocol.asl") }

{ register_function("carrying.gold", 0, "carrying_gold") }
{ register_function("jia.path_length", 4, "jia.path_length") }

/* ── Initial beliefs ───────────────────────────────────────────────────── */

free.
my_capacity(3).
lot_of_gold_threshold(3).   // >= this many golds in quadrant → "lot of gold"
low_gold_threshold(2).       // < this many golds → "low gold" (may be redirected)
search_gold_strategy(quadrant).  // wait for quadrant assignment, then scan

/* ── Rules ─────────────────────────────────────────────────────────────── */

// True during the first 10 % of the simulation
in_explore_phase :-
    pos(_,_,Step) & steps(_,Total) & 10 * Step < Total.

// Count gold beliefs that lie inside our assigned quadrant
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


/* ── Initialisation ─────────────────────────────────────────────────────── */

+pos(_,_,0)
  <- ?gsize(S,_,_);
     .my_name(Me);
     .print(Me, " starting simulation ", S);
     !inform_gsize_to_leader(S);
     !choose_goal.

// Only miner1 sends the world description to the leader (avoids duplicates)
+!inform_gsize_to_leader(S) : .my_name(miner1)
  <- ?depot(S,DX,DY);
     .send(leader,tell,depot(S,DX,DY));
     ?gsize(S,W,H);
     .send(leader,tell,gsize(S,W,H)).
+!inform_gsize_to_leader(_).


/* ── Goal selection ─────────────────────────────────────────────────────── */

// Phase 1: always scan — never fetch
@cg_explore[atomic]
+!choose_goal : in_explore_phase
  <- .print("Exploration phase: scanning quadrant.");
     !change_to_search.

// Transition: first call after exploration ends — report summary then mine
@cg_transition[atomic]
+!choose_goal : not in_explore_phase & not exploration_reported
  <- +exploration_reported;
     !report_exploration_summary;
     !choose_goal.  // recurse once to pick actual mining goal

// Phase 2: fetch closest worthwhile gold
@cg_fetch[atomic]
+!choose_goal
  : container_has_space &
    .findall(gold(X,Y), gold(X,Y), LG) &
    evaluate_golds(LG, LD) &
    .length(LD) > 0 &
    .min(LD, d(_, NewG, _)) &
    worthwhile(NewG)
  <- .print("Fetching ", NewG);
     !change_to_fetch(NewG).

// Drop gold at depot
+!choose_goal : carrying_gold(NG) & NG > 0
  <- !change_to_goto_depot.

// Default: keep scanning
+!choose_goal <- !change_to_search.


/* ── Exploration-phase report ───────────────────────────────────────────── */

+!report_exploration_summary
  : quadrant(X1,Y1,X2,Y2) & quadrant_gold_count(Count) & .my_name(Me)
  <- .print("Exploration done: found ", Count, " golds in quadrant.");
     // Always inform the leader of the final tally
     .send(leader, tell, quadrant_explored(Me, X1, Y1, X2, Y2, Count));
     // Also flag "lot of gold" if threshold reached (in case it wasn't already sent)
     if (not reported_lot_of_gold) {
         lot_of_gold_threshold(Thresh);
         if (Count >= Thresh) {
             .print("Reporting LOT OF GOLD to leader (", Count, ").");
             +reported_lot_of_gold;
             .send(leader, tell, lot_of_gold_in_quadrant(Me, X1, Y1, X2, Y2))
         }
     }.
+!report_exploration_summary.   // no quadrant yet — do nothing


/* ── Change-goal helpers ─────────────────────────────────────────────────── */

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


/* ── Gold / cell perception ─────────────────────────────────────────────── */

// EXPLORATION PHASE — record and report, but keep scanning (do NOT fetch)
@pcell_explore[atomic]
+cell(X,Y,gold) : in_explore_phase & not gold(X,Y)
  <- .print("Gold noted during exploration: ", gold(X,Y));
     +gold(X,Y);
     .send(leader, tell, gold(X,Y));
     .broadcast(tell, gold(X,Y));  // let other agents bid
     !check_lot_of_gold.

// MINING PHASE — record, report, then reconsider goal
@pcell_mine[atomic]
+cell(X,Y,gold) : container_has_space & not gold(X,Y)
  <- .print("Gold found: ", gold(X,Y));
     +gold(X,Y);
     .send(leader, tell, gold(X,Y));
     .broadcast(tell, gold(X,Y));
     !check_lot_of_gold;
     !choose_goal.

// Full container — just register so others can pick it up
+cell(X,Y,gold) : not container_has_space & not gold(X,Y)
  <- +gold(X,Y);
     +announced(gold(X,Y));
     .send(leader, tell, gold(X,Y));
     .broadcast(tell, gold(X,Y)).

// Cell now empty — remove from knowledge and inform leader
+cell(X,Y,empty) : gold(X,Y) & not .desire(fetch_gold(gold(X,Y)))
  <- !remove(gold(X,Y));
     .send(leader, tell, picked(gold(X,Y)));
     .broadcast(tell, picked(gold(X,Y))).


/* ── Lot-of-gold check (reported at most once per simulation) ─────────── */

+!check_lot_of_gold
  : not reported_lot_of_gold &
    quadrant_gold_count(Count) &
    lot_of_gold_threshold(Thresh) &
    Count >= Thresh &
    quadrant(X1,Y1,X2,Y2) &
    .my_name(Me)
  <- .print("LOT OF GOLD in quadrant (", Count, "). Alerting leader.");
     +reported_lot_of_gold;
     .send(leader, tell, lot_of_gold_in_quadrant(Me, X1, Y1, X2, Y2)).
+!check_lot_of_gold.


/* ── Leader-issued redirection ──────────────────────────────────────────── */

// Leader redirects this miner to a richer quadrant
@redir_miner[atomic]
+mine_in_quadrant(X1,Y1,X2,Y2)[source(leader)]
  <- .my_name(Me);
     .print(Me, " redirected to quadrant (", X1,",",Y1,")-(", X2,",",Y2,")");
     -exploration_reported;      // allow re-reporting for new quadrant
     -reported_lot_of_gold;
     .drop_all_desires;
     +free;
     -+quadrant(X1,Y1,X2,Y2).   // triggers +quadrant in search_quadrant.asl
                                 // which calls !!choose_goal automatically


/* ── Belief-removal helper ──────────────────────────────────────────────── */

+!remove(gold(X,Y))
  <- .abolish(gold(X,Y));
     .abolish(committed_to(gold(X,Y),_,_));
     .abolish(picked(gold(X,Y)));
     .abolish(announced(gold(X,Y)));
     .abolish(allocated(gold(X,Y),_)).


/* ── End of simulation ──────────────────────────────────────────────────── */

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
     .print("Quadrant miner -- END ", S, ": ", R).

@rl[atomic]
+restart
  <- .abolish(exploration_reported);
     .abolish(reported_lot_of_gold);
     .drop_all_desires;
     !choose_goal.
