// Scout Agent
//
// Agent 5 (scout1): right region of the map
// Agent 6 (scout2): left region of the map
//
// Default behaviour — purely reactive, driven by +pos each step:
//   1. If carrying gold  → deliver to depot.
//   2. If gold underfoot → pick it up.
//   3. If gold adjacent  → move toward it.
//   4. If enemy visible  → follow it (harassment + intelligence gathering).
//   5. Otherwise         → random patrol inside home region.
//
// On leader order "mine_in_quadrant(X1,Y1,X2,Y2)":
//   Switch to MINING MODE: use goal-based quadrant scan (search_quadrant.asl)
//   to systematically sweep the area and mine all gold found.
//   After the quadrant is exhausted, automatically return to patrol.
//
// All perceived gold positions are forwarded to the leader.
// Enemies spotted are also reported.

// ── Override for search_quadrant.asl failure handler ────────────────────
// Must appear BEFORE the include so Jason tries it first.
// When quadrant search fails in mining mode → exit mining, back to patrol.
@sq_fail_mining
-!search_gold(quadrant) : mining_mode
  <- .print("Scout: quadrant exhausted, returning to patrol.");
     -mining_mode;
     .abolish(quadrant(_,_,_,_));
     .abolish(last_checked(_,_));
     +free.          // re-enable reactive +pos patrol handlers

{ include("moving.asl") }
{ include("search_quadrant.asl") }
{ include("fetch_gold.asl") }
{ include("goto_depot.asl") }
{ include("allocation_protocol.asl") }

{ register_function("carrying.gold", 0, "carrying_gold") }
{ register_function("jia.path_length", 4, "jia.path_length") }

/* ── Initial beliefs ───────────────────────────────────────────────────── */

free.
my_capacity(3).
// region(right) or region(left) injected via mas2j initial beliefs

/* ── Rules ─────────────────────────────────────────────────────────────── */

go_depot :- carrying_gold(3).
go_depot :- carrying_gold(N) & N > 0 & pos(_,_,Step) & steps(_,NS) & Step+200 > NS.

// A random position in the scout's home half of the map
patrol_pos(NX, NY) :-
    pos(AgX,AgY,_) &
    gsize(_,W,_) &
    jia.random(RX,20) &
    jia.random(RY,20) &
    RawX = (RX-10)+AgX &
    RawY = (RY-10)+AgY &
    RawY >= 0 &
    (region(right) ->
        (RawX >= W/2 -> NX = RawX ; NX = W/2)
    ;
        (RawX < W/2 -> NX = RawX ; NX = 0)
    ) &
    NY = RawY &
    not jia.obstacle(NX,NY).

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
     .print("Scout ", Me, " starting simulation ", S).


/* ── Reactive patrol mode (+pos triggers, active when free & not mining) ── */

// 1. Deliver gold to depot
+pos(X,Y,_) : free & not mining_mode & go_depot & depot(_,X,Y)
  <- .print("Scout: at depot, dropping gold.");
     do(drop).

+pos(X,Y,_) : free & not mining_mode & go_depot & depot(_,DX,DY)
  <- jia.direction(X,Y,DX,DY,D); do(D).

// 2. Gold underfoot — pick it up and tell the leader
+pos(X,Y,_) : free & not mining_mode & cell(X,Y,gold) & container_has_space
  <- .print("Scout: picking gold at ", X, ",", Y);
     do(pick);
     .send(leader, tell, gold(X,Y)).

// 3. Gold adjacent — step toward it
+pos(X,Y,_) : free & not mining_mode & cell(GX,GY,gold) & container_has_space
  <- jia.direction(X,Y,GX,GY,D); do(D).

// 4. Enemy visible — follow and report
+pos(X,Y,_) : free & not mining_mode & cell(EX,EY,enemy)
  <- .print("Scout: following enemy at ", EX, ",", EY);
     jia.direction(X,Y,EX,EY,D);
     do(D);
     .send(leader, tell, enemy_at(EX,EY)).

// 5. Patrol home region
+pos(X,Y,_) : free & not mining_mode & patrol_pos(NX,NY)
  <- jia.direction(X,Y,NX,NY,D); do(D).

// 6. Fallback — skip turn if patrol_pos fails (e.g. surrounded by obstacles)
+pos(_,_,_) : free & not mining_mode
  <- do(skip).


/* ── Leader order: switch to mining mode ────────────────────────────────── */

@mine_order[atomic]
+mine_in_quadrant(X1,Y1,X2,Y2)[source(leader)]
  <- .my_name(Me);
     .print("Scout ", Me, ": mining order (", X1,",",Y1,")-(", X2,",",Y2,")");
     +mining_mode;
     .drop_all_desires;
     -free;                          // disable reactive patrol handlers
     -+quadrant(X1,Y1,X2,Y2).        // triggers +quadrant in search_quadrant.asl
                                     // → sets strategy=quadrant, calls !!choose_goal


/* ── Goal selection (used by mining mode and allocation protocol) ──────── */

// Fetch known worthwhile gold
@sg_fetch[atomic]
+!choose_goal
  : container_has_space &
    .findall(gold(X,Y), gold(X,Y), LG) &
    evaluate_golds(LG, LD) &
    .length(LD) > 0 &
    .min(LD, d(_, NewG, _)) &
    worthwhile(NewG)
  <- !change_to_fetch(NewG).

// Deliver carried gold
+!choose_goal : carrying_gold(NG) & NG > 0
  <- !change_to_goto_depot.

// Mining mode: continue quadrant scan
+!choose_goal : mining_mode
  <- !change_to_search.

// Default (back to patrol): re-enable reactive handlers
+!choose_goal
  <- .print("Scout: returning to patrol.");
     +free.


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

@pcell_scout[atomic]
+cell(X,Y,gold) : not gold(X,Y)
  <- .print("Scout: new gold at ", X, ",", Y);
     +gold(X,Y);
     .send(leader, tell, gold(X,Y));
     .broadcast(tell, gold(X,Y));
     // In mining mode, reconsider current goal
     if (mining_mode) { !choose_goal }.

+cell(X,Y,empty) : gold(X,Y) & not .desire(fetch_gold(gold(X,Y)))
  <- !remove(gold(X,Y));
     .send(leader, tell, picked(gold(X,Y)));
     .broadcast(tell, picked(gold(X,Y))).


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
     -mining_mode;
     .abolish(quadrant(_,_,_,_));
     .abolish(last_checked(_,_));
     -+free;
     .print("Scout -- END ", S, ": ", R).

@sl_rl[atomic]
+restart
  <- -mining_mode;
     .drop_all_desires;
     +free.
