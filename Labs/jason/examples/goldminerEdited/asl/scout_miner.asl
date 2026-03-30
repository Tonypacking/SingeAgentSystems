// scout_miner agent
//
// Roles:
//   scout_miner1-4: each assigned one quadrant by scout_leader; scouts it
//                   and when >= gold_threshold golds found there, broadcasts
//                   mine_quadrant(...) to call all teammates in.
//   scout_miner5-6: start with near_unvisited search; redirect to any rich
//                   quadrant announced by a scout.
//
// After broadcasting mine_quadrant, the agent continues mining its own quadrant.
// All other agents (including unassigned ones) switch their quadrant to the rich one.

{ include("moving.asl") }
{ include("search_unvisited.asl") }
{ include("search_quadrant.asl") }
{ include("fetch_gold.asl") }
{ include("goto_depot.asl") }

{ register_function("carrying.gold",0,"carrying_gold") }
{ register_function("jia.path_length",4,"jia.path_length") }

/* ------- beliefs ------- */

free.
my_capacity(3).
search_gold_strategy(near_unvisited).   // overridden to quadrant once assigned

gold_in_my_quadrant(0).                 // count of gold seen inside my quadrant
gold_threshold(2).                      // how many to trigger the mine_quadrant call

/* ------- startup ------- */

+pos(_,_,0)
  <- ?gsize(S,_,_);
     .print("Starting simulation ", S);
     !inform_gsize_to_leader(S);
     !choose_goal.

// Only miner1 tells the leader the grid size (same convention as original)
+!inform_gsize_to_leader(S) : .my_name(scout_miner1)
  <- ?depot(S,DX,DY);
     .send(scout_leader, tell, depot(S,DX,DY));
     ?gsize(S,W,H);
     .send(scout_leader, tell, gsize(S,W,H)).
+!inform_gsize_to_leader(_).

/* ------- goal selection ------- */

@cgod2[atomic]
+!choose_goal
  :  container_has_space &
     .findall(gold(X,Y), gold(X,Y), LG) &
     evaluate_golds(LG,LD) &
     .length(LD) > 0 &
     .min(LD, d(D,NewG,_)) &
     worthwhile(NewG)
  <- .print("Next gold: ",NewG);
     !change_to_fetch(NewG).

+!choose_goal : carrying_gold(NG) & NG > 0
  <- !change_to_goto_depot.

+!choose_goal
  <- !change_to_search.

/* ------- goal transitions ------- */

+!change_to_goto_depot : .desire(goto_depot).
+!change_to_goto_depot : .desire(fetch_gold(G))
  <- .drop_desire(fetch_gold(G)); !change_to_goto_depot.
+!change_to_goto_depot
  <- -free; !!goto_depot.

+!change_to_fetch(G) : .desire(fetch_gold(G)).
+!change_to_fetch(G) : .desire(goto_depot)
  <- .drop_desire(goto_depot); !change_to_fetch(G).
+!change_to_fetch(G) : .desire(fetch_gold(OtherG))
  <- .drop_desire(fetch_gold(OtherG)); !change_to_fetch(G).
+!change_to_fetch(G)
  <- -free; !!fetch_gold(G).

+!change_to_search : search_gold_strategy(S)
  <- .print("Searching: ",S);
     -free; +free;
     .drop_all_desires;
     !!search_gold(S).

/* ------- gold evaluation rules ------- */

evaluate_golds([],[]) :- true.
evaluate_golds([gold(GX,GY)|R], [d(U,gold(GX,GY),Annot)|RD])
  :- evaluate_gold(gold(GX,GY),U,Annot) & evaluate_golds(R,RD).
evaluate_golds([_|R], RD)
  :- evaluate_golds(R,RD).

evaluate_gold(gold(X,Y), Utility, Annot)
  :- pos(AgX,AgY,_) &
     jia.path_length(AgX,AgY,X,Y,D) &
     jia.add_fatigue(D,Utility) &
     check_commit(gold(X,Y),Utility,Annot).

check_commit(_,0,in_my_place)   :- true.
check_commit(G,_,not_committed) :- not committed_to(G,_,_).
check_commit(gold(X,Y), MyD, committed_by(Ag,at(OtX,OtY),far(OtD)))
  :- committed_to(gold(X,Y),_,Ag) &
     jia.ag_pos(Ag,OtX,OtY) &
     jia.path_length(OtX,OtY,X,Y,OtD) &
     MyD < OtD.

worthwhile(gold(_,_)) :- carrying_gold(0).
worthwhile(gold(GX,GY))
  :- carrying_gold(NG) & NG > 0 &
     pos(AgX,AgY,Step) &
     depot(_,DX,DY) &
     steps(_,TotalSteps) &
     AvailableSteps = TotalSteps - Step &
     jia.add_fatigue(jia.path_length(AgX,AgY,GX,GY), NG,   CN4) &
     jia.add_fatigue(jia.path_length(GX,GY,DX,DY),   NG+1, CN5) &
     AvailableSteps > (CN4 + CN5) * 1.1.

/* ------- perception: new gold cell ------- */

// Single atomic handler for any new gold cell
@pcell_new[atomic]
+cell(X,Y,gold) : not gold(X,Y)
  <- +gold(X,Y);
     !count_if_in_quadrant(X,Y);
     !check_quadrant_richness;
     !choose_goal.

// Count the gold only if it lies inside my assigned quadrant
+!count_if_in_quadrant(X,Y)
  :  quadrant(X1,Y1,X2,Y2) & X >= X1 & X =< X2 & Y >= Y1 & Y =< Y2
  <- ?gold_in_my_quadrant(N);
     N1 is N + 1;
     -+gold_in_my_quadrant(N1);
     .print("Gold in my quadrant: ",N1," total").
+!count_if_in_quadrant(_,_).  // outside my quadrant or no quadrant yet — do nothing

// Gold that was here is now gone (someone else picked it)
+cell(X,Y,empty)
  :  gold(X,Y) & not .desire(fetch_gold(gold(X,Y)))
  <- !remove(gold(X,Y));
     .print("Gold at ",X,",",Y," is gone. Announcing.");
     .broadcast(tell, picked(gold(X,Y))).

/* ------- quadrant richness protocol ------- */

// Broadcast mine_quadrant once when the gold count hits the threshold
+!check_quadrant_richness
  :  gold_in_my_quadrant(N) &
     gold_threshold(T) &
     N >= T &
     quadrant(X1,Y1,X2,Y2) &
     not announced_rich_quadrant
  <- N_int is integer(N);   // ensure N prints as a number
     .print("Quadrant RICH (",N_int," golds)! Calling teammates to [",X1,",",Y1,"] - [",X2,",",Y2,"]");
     +announced_rich_quadrant;
     .broadcast(tell, mine_quadrant(X1,Y1,X2,Y2)).
+!check_quadrant_richness.   // threshold not reached yet, or already announced

// A teammate has found a rich quadrant — redirect there
@rich_quad[atomic]
+mine_quadrant(X1,Y1,X2,Y2)[source(Other)]
  :  .my_name(Me) & Me \== Other &
     not quadrant(X1,Y1,X2,Y2)   // skip if already in this quadrant
  <- .print("Redirecting to rich quadrant announced by ",Other,": [",X1,",",Y1,"]-[",X2,",",Y2,"]");
     .abolish(quadrant(_,_,_,_));
     +quadrant(X1,Y1,X2,Y2);
     .abolish(last_checked(_,_));   // don't resume old quadrant scan position
     -+search_gold_strategy(quadrant);
     !change_to_search.
+mine_quadrant(_,_,_,_).  // already in that quadrant — ignore

// Teammate announced gold while going to depot — re-evaluate goals
+gold(X,Y)[source(A)] : A \== self <- !choose_goal.

/* ------- end of simulation ------- */

+end_of_simulation(S,R)
  <- .drop_all_desires;
     !remove(gold(_,_));
     .abolish(picked(_));
     -+search_gold_strategy(near_unvisited);
     .abolish(quadrant(_,_,_,_));
     .abolish(last_checked(_,_));
     .abolish(announced_rich_quadrant);
     -+gold_in_my_quadrant(0);
     -+free;
     .print("-- END ",S,": ",R).

+!remove(gold(X,Y))
  <- .abolish(gold(X,Y));
     .abolish(committed_to(gold(X,Y),_,_));
     .abolish(picked(gold(X,Y)));
     .abolish(announced(gold(X,Y))).

@rl[atomic]
+restart
  <- .print("*** Restarting!");
     .drop_all_desires;
     !choose_goal.
