// Advanced Scout Agent (ported from scout.asl in gold-miners-II)
//
// adv5: right region of the map  (region(right) defined in adv5.asl)
// adv6: left region of the map   (region(left)  defined in adv6.asl)
//
// Default behaviour — reactive patrol driven by +pos each step:
//   1. If carrying gold      -> deliver to depot.
//   2. If gold underfoot     -> pick it up.
//   3. If gold adjacent      -> move toward it.
//   4. If enemy visible      -> follow it (harassment + intelligence).
//   5. Otherwise             -> random patrol inside home region.
//
// On advleader order "mine_in_quadrant(X1,Y1,X2,Y2)":
//   Switch to MINING MODE: systematic quadrant sweep via search_quadrant.asl.
//   After quadrant is exhausted, automatically return to patrol.

@advsq_fail_mining
-!search_gold(quadrant) : mining_mode
  <- .print("Scout: quadrant exhausted, returning to patrol.");
     -mining_mode;
     .abolish(quadrant(_,_,_,_));
     .abolish(last_checked(_,_));
     +free.

{ include("moving.asl") }
{ include("search_quadrant.asl") }
{ include("fetch_gold.asl") }
{ include("goto_depot.asl") }
{ include("adv_allocation_protocol.asl") }

{ register_function("carrying.gold", 0, "carrying_gold") }
{ register_function("jia.path_length", 4, "jia.path_length") }

/* -- Initial beliefs -- */

free.
my_capacity(3).

/* -- Rules -- */

go_depot :- carrying_gold(3).
go_depot :- carrying_gold(N) & N > 0 & pos(_,_,Step) & steps(_,NS) & Step+200 > NS.

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


/* -- Initialisation -- */

+pos(_,_,0)
  <- ?gsize(S,_,_);
     .my_name(Me);
     .print("AdvScout ", Me, " starting simulation ", S).


/* -- Reactive patrol mode -- */

+pos(X,Y,_) : free & not mining_mode & go_depot & depot(_,X,Y)
  <- .print("Scout: at depot, dropping gold.");
     do(drop).

+pos(X,Y,_) : free & not mining_mode & go_depot & depot(_,DX,DY)
  <- jia.direction(X,Y,DX,DY,D); do(D).

+pos(X,Y,_) : free & not mining_mode & cell(X,Y,gold) & container_has_space
  <- .print("Scout: picking gold at ", X, ",", Y);
     do(pick);
     .send(advleader, tell, gold(X,Y)).

+pos(X,Y,_) : free & not mining_mode & cell(GX,GY,gold) & container_has_space
  <- jia.direction(X,Y,GX,GY,D); do(D).

+pos(X,Y,_) : free & not mining_mode & cell(EX,EY,enemy)
  <- .print("Scout: following enemy at ", EX, ",", EY);
     jia.direction(X,Y,EX,EY,D);
     do(D);
     .send(advleader, tell, enemy_at(EX,EY)).

+pos(X,Y,_) : free & not mining_mode & patrol_pos(NX,NY)
  <- jia.direction(X,Y,NX,NY,D); do(D).

+pos(_,_,_) : free & not mining_mode
  <- do(skip).


/* -- Leader order: switch to mining mode -- */

@advmine_order[atomic]
+mine_in_quadrant(X1,Y1,X2,Y2)[source(advleader)]
  <- .my_name(Me);
     .print("AdvScout ", Me, ": mining order (", X1,",",Y1,")-(", X2,",",Y2,")");
     +mining_mode;
     .drop_all_desires;
     -free;
     -+quadrant(X1,Y1,X2,Y2).


/* -- Goal selection (used by mining mode and allocation protocol) -- */

@advsg_fetch[atomic]
+!choose_goal
  : container_has_space &
    .findall(gold(X,Y), gold(X,Y), LG) &
    evaluate_golds(LG, LD) &
    .length(LD) > 0 &
    .min(LD, d(_, NewG, _)) &
    worthwhile(NewG)
  <- !advscout_change_to_fetch(NewG).

+!choose_goal : carrying_gold(NG) & NG > 0
  <- !advscout_change_to_goto_depot.

+!choose_goal : mining_mode
  <- !advscout_change_to_search.

+!choose_goal
  <- .print("Scout: returning to patrol.");
     +free.


/* -- Change-goal helpers -- */

+!advscout_change_to_goto_depot : .desire(goto_depot).
+!advscout_change_to_goto_depot : .desire(fetch_gold(G))
  <- .drop_desire(fetch_gold(G)); !advscout_change_to_goto_depot.
+!advscout_change_to_goto_depot <- -free; !!goto_depot.

+!advscout_change_to_fetch(G) : .desire(fetch_gold(G)).
+!advscout_change_to_fetch(G) : .desire(goto_depot)
  <- .drop_desire(goto_depot); !advscout_change_to_fetch(G).
+!advscout_change_to_fetch(G) : .desire(fetch_gold(OG))
  <- .drop_desire(fetch_gold(OG)); !advscout_change_to_fetch(G).
+!advscout_change_to_fetch(G) <- -free; !!fetch_gold(G).

+!advscout_change_to_search : search_gold_strategy(S)
  <- -free; +free; .drop_all_desires; !!search_gold(S).


/* -- Gold / cell perception -- */

@advcell_scout[atomic]
+cell(X,Y,gold) : not gold(X,Y)
  <- .print("Scout: new gold at ", X, ",", Y);
     +gold(X,Y);
     .send(advleader, tell, gold(X,Y));
     .broadcast(tell, gold(X,Y));
     if (mining_mode) { !choose_goal }.

+cell(X,Y,empty) : gold(X,Y) & not .desire(fetch_gold(gold(X,Y)))
  <- !remove(gold(X,Y));
     .send(advleader, tell, picked(gold(X,Y)));
     .broadcast(tell, picked(gold(X,Y))).


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
     -mining_mode;
     .abolish(quadrant(_,_,_,_));
     .abolish(last_checked(_,_));
     -+free;
     .print("AdvScout -- END ", S, ": ", R).

@advscout_rl[atomic]
+restart
  <- -mining_mode;
     .drop_all_desires;
     +free.
