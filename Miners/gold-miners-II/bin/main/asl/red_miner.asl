// Red Miner Agent
// Identical logic to miner.asl — only two things differ:
//   1. Sends gsize/depot to "rleader" (not "leader"), and only rminer1 does it.
//   2. Uses allocation_protocol_red.asl so bids go to "rleader".

{ include("moving.asl") }
{ include("search_unvisited.asl") }
{ include("search_quadrant.asl") }
{ include("fetch_gold.asl") }
{ include("goto_depot.asl") }
{ include("allocation_protocol_red.asl") }   // bids → rleader

{ register_function("carrying.gold",0,"carrying_gold") }
{ register_function("jia.path_length",4,"jia.path_length") }

free.
my_capacity(3).
search_gold_strategy(near_unvisited).

/* Initial goal */
+pos(_,_,0)
  <- ?gsize(S,_,_);
     .print("Red miner starting simulation ", S);
     !inform_gsize_to_leader(S);
     !choose_goal.

+!inform_gsize_to_leader(S) : .my_name(rminer1)
   <- ?depot(S,DX,DY);
      .send(rleader,tell,depot(S,DX,DY));
      ?gsize(S,W,H);
      .send(rleader,tell,gsize(S,W,H)).
+!inform_gsize_to_leader(_).


/* Goal selection — unchanged from miner.asl */
@rcgod2[atomic]
+!choose_goal
 :  container_has_space &
    .findall(gold(X,Y),gold(X,Y),LG) &
    evaluate_golds(LG,LD) &
    .print("All golds=",LG,", evaluation=",LD) &
    .length(LD) > 0 &
    .min(LD,d(D,NewG,_)) &
    worthwhile(NewG)
 <- .print("Gold options are ",LD,". Next gold is ",NewG);
    !change_to_fetch(NewG).

+!choose_goal : carrying_gold(NG) & NG > 0
 <- !change_to_goto_depot.

+!choose_goal <- !change_to_search.

/* Change-goal helpers */
+!change_to_goto_depot : .desire(goto_depot)
  <- .print("do not need to change to goto_depot").
+!change_to_goto_depot : .desire(fetch_gold(G))
  <- .drop_desire(fetch_gold(G)); !change_to_goto_depot.
+!change_to_goto_depot <- -free; !!goto_depot.

+!change_to_fetch(G) : .desire(fetch_gold(G)).
+!change_to_fetch(G) : .desire(goto_depot)
  <- .drop_desire(goto_depot); !change_to_fetch(G).
+!change_to_fetch(G) : .desire(fetch_gold(OtherG))
  <- .drop_desire(fetch_gold(OtherG)); !change_to_fetch(G).
+!change_to_fetch(G) <- -free; !!fetch_gold(G).

+!change_to_search : search_gold_strategy(S)
  <- .print("New goal is find gold: ",S);
     -free; +free; .drop_all_desires; !!search_gold(S).

/* Gold evaluation rules — unchanged */
evaluate_golds([],[]) :- true.
evaluate_golds([gold(GX,GY)|R],[d(U,gold(GX,GY),Annot)|RD])
  :- evaluate_gold(gold(GX,GY),U,Annot) & evaluate_golds(R,RD).
evaluate_golds([_|R],RD) :- evaluate_golds(R,RD).

evaluate_gold(gold(X,Y),Utility,Annot)
  :- pos(AgX,AgY,_) & jia.path_length(AgX,AgY,X,Y,D) &
     jia.add_fatigue(D,Utility) & check_commit(gold(X,Y),Utility,Annot).

check_commit(_,0,in_my_place)   :- true.
check_commit(G,_,not_committed) :- not committed_to(G,_,_).
check_commit(gold(X,Y),MyD,committed_by(Ag,at(OtX,OtY),far(OtD)))
  :- committed_to(gold(X,Y),_,Ag) &
     jia.ag_pos(Ag,OtX,OtY) &
     jia.path_length(OtX,OtY,X,Y,OtD) &
     MyD < OtD.

worthwhile(gold(_,_)) :- carrying_gold(0).
worthwhile(gold(GX,GY)) :-
     carrying_gold(NG) & NG > 0 &
     pos(AgX,AgY,Step) & depot(_,DX,DY) & steps(_,TotalSteps) &
     AvailableSteps = TotalSteps - Step &
     jia.add_fatigue(jia.path_length(AgX,AgY,GX,GY),NG,  CN4) &
     jia.add_fatigue(jia.path_length(GX,  GY,DX,DY),NG+1,CN5) &
     AvailableSteps > (CN4 + CN5) * 1.1.

/* Gold perception — unchanged */
@rpcell0[atomic]
+cell(X,Y,gold) : container_has_space & not gold(X,Y)
  <- .print("Gold perceived: ",gold(X,Y)); +gold(X,Y); !choose_goal.

+cell(X,Y,gold) : not container_has_space & not gold(X,Y) & not committed(gold(X,Y),_,_)
  <- +gold(X,Y); +announced(gold(X,Y));
     .print("Announcing ",gold(X,Y)," to others");
     .broadcast(tell,gold(X,Y)).

+cell(X,Y,empty) : gold(X,Y) & not .desire(fetch_gold(gold(X,Y)))
  <- !remove(gold(X,Y));
     .broadcast(tell,picked(gold(X,Y))).

/* End of simulation */
+end_of_simulation(S,R)
  <- .drop_all_desires; !remove(gold(_,_)); .abolish(picked(_));
     -+search_gold_strategy(near_unvisited);
     .abolish(quadrant(_,_,_,_)); .abolish(last_checked(_,_));
     -+free;
     .print("Red miner -- END ",S,": ",R).

+!remove(gold(X,Y))
  <- .abolish(gold(X,Y)); .abolish(committed_to(gold(X,Y),_,_));
     .abolish(picked(gold(X,Y))); .abolish(announced(gold(X,Y)));
     .abolish(allocated(gold(X,Y),_)).

@rrl[atomic]
+restart <- .print("Red miner restarting!"); .drop_all_desires; !choose_goal.
