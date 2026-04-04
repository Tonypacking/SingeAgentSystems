// smart miner agent

{ include("moving.asl") }
{ include("search_unvisited.asl") }
{ include("search_quadrant.asl") }
{ include("fetch_gold.asl") }
{ include("goto_depot.asl") }
{ include("smart_allocation_protocol.asl") }

{ register_function("carrying.gold",0,"carrying_gold") }
{ register_function("jia.path_length",4,"jia.path_length") }

free.
my_capacity(3).
search_gold_strategy(near_unvisited).

+pos(_,_,0)
  <- ?gsize(S,_,_);
     .print("Starting smart simulation ", S);
     !inform_world_to_leader(S);
     ?pos(X,Y,_);
     .send(smartleader,tell,init_pos(S,X,Y));
     !choose_goal.

+!inform_world_to_leader(S) : .my_name(smart1)
   <- ?depot(S,DX,DY);
      .send(smartleader,tell,depot(S,DX,DY));
      ?gsize(S,W,H);
      .send(smartleader,tell,gsize(S,W,H)).
+!inform_world_to_leader(_).

@alloc_goal[atomic]
+!choose_goal
 :  container_has_space &
    .my_name(Me) &
    .findall(G,allocated(G,Me),MyGolds) &
    evaluate_golds(MyGolds,LD) &
    .length(LD) > 0 &
    .min(LD,d(_,NewG,_)) &
    worthwhile(NewG)
 <- .print("Allocated options are ",LD,". Next gold is ",NewG);
    !change_to_fetch(NewG).

+!choose_goal
 :  container_has_space &
    .findall(gold(X,Y),(gold(X,Y) & gold_in_sector(gold(X,Y))),LG) &
    evaluate_golds(LG,LD) &
    .length(LD) > 0 &
    .min(LD,d(_,NewG,_)) &
    worthwhile(NewG)
 <- .print("Sector gold options are ",LD,". Next gold is ",NewG);
    !change_to_fetch(NewG).

+!choose_goal
 :  container_has_space &
    .findall(gold(X,Y),gold(X,Y),LG) &
    evaluate_golds(LG,LD) &
    .length(LD) > 0 &
    .min(LD,d(_,NewG,_)) &
    worthwhile(NewG)
 <- .print("Global gold options are ",LD,". Next gold is ",NewG);
    !change_to_fetch(NewG).

+!choose_goal
 :  carrying_gold(NG) & NG > 0
 <- !change_to_goto_depot.

+!choose_goal
 <- !change_to_search.

+!change_to_goto_depot
  :  .desire(goto_depot)
  <- .print("Already heading to depot.").
+!change_to_goto_depot
  :  .desire(fetch_gold(G))
  <- .drop_desire(fetch_gold(G));
     !change_to_goto_depot.
+!change_to_goto_depot
  <- -free;
     !!goto_depot.

+!change_to_fetch(G)
  :  .desire(fetch_gold(G)).
+!change_to_fetch(G)
  :  .desire(goto_depot)
  <- .drop_desire(goto_depot);
     !change_to_fetch(G).
+!change_to_fetch(G)
  :  .desire(fetch_gold(OtherG))
  <- .drop_desire(fetch_gold(OtherG));
     !change_to_fetch(G).
+!change_to_fetch(G)
  <- -free;
     !!fetch_gold(G).

+!change_to_search
  :  search_gold_strategy(S)
  <- .print("Smart miner searching with strategy ",S);
     -free;
     +free;
     .drop_all_desires;
     !!search_gold(S).

evaluate_golds([],[]) :- true.
evaluate_golds([gold(GX, GY)|R],[d(U,gold(GX,GY),Annot)|RD])
  :- evaluate_gold(gold(GX,GY),U,Annot) &
     evaluate_golds(R,RD).
evaluate_golds([_|R],RD)
  :- evaluate_golds(R,RD).

evaluate_gold(gold(X,Y),Utility,Annot)
  :- pos(AgX,AgY,_) &
     jia.path_length(AgX,AgY,X,Y,D) &
     jia.add_fatigue(D,Base) &
     adjust_utility(gold(X,Y),Base,Utility) &
     check_commit(gold(X,Y),Utility,Annot).

adjust_utility(G,Base,Utility) :-
     gold_in_sector(G) &
     Base > 1 &
     Utility = Base - 1.
adjust_utility(_,Base,Utility) :-
     Utility = Base.

check_commit(_,0,in_my_place) :- true.
check_commit(G,_,not_committed) :- not committed_to(G,_,_).
check_commit(gold(X,Y),MyD,committed_by(Ag,at(OtX,OtY),far(OtD)))
  :- committed_to(gold(X,Y),_,Ag) &
     jia.ag_pos(Ag,OtX,OtY) &
     jia.path_length(OtX,OtY,X,Y,OtD) &
     MyD < OtD.

gold_in_sector(gold(X,Y)) :-
     quadrant(X1,Y1,X2,Y2) &
     X >= X1 & X <= X2 &
     Y >= Y1 & Y <= Y2.

worthwhile(gold(_,_)) :-
     carrying_gold(0).
worthwhile(gold(GX,GY)) :-
     carrying_gold(1) &
     pos(AgX,AgY,Step) &
     depot(_,DX,DY) &
     steps(_,TotalSteps) &
     AvailableSteps = TotalSteps - Step &
     jia.path_length(AgX,AgY,GX,GY,RawToGold) &
     jia.add_fatigue(RawToGold,1,CostToGold) &
     jia.path_length(GX,GY,DX,DY,RawToDepot) &
     jia.add_fatigue(RawToDepot,2,CostToDepot) &
     AvailableSteps > (CostToGold + CostToDepot).
worthwhile(gold(GX,GY)) :-
     carrying_gold(2) &
     pos(AgX,AgY,Step) &
     depot(_,DX,DY) &
     steps(_,TotalSteps) &
     AvailableSteps = TotalSteps - Step &
     jia.path_length(AgX,AgY,GX,GY,RawToGold) &
     RawToGold <= 8 &
     jia.add_fatigue(RawToGold,2,CostToGold) &
     jia.path_length(GX,GY,DX,DY,RawToDepot) &
     jia.add_fatigue(RawToDepot,3,CostToDepot) &
     AvailableSteps > (CostToGold + CostToDepot) * 1.05.

@pcell0[atomic]
+cell(X,Y,gold)
  :  container_has_space &
     not gold(X,Y)
  <- .print("Gold perceived: ",gold(X,Y));
     +gold(X,Y);
     !choose_goal.

+cell(X,Y,gold)
  :  not container_has_space & not gold(X,Y) & not committed(gold(X,Y),_,_)
  <- +gold(X,Y);
     +announced(gold(X,Y));
     .print("Announcing ",gold(X,Y)," to others");
     .broadcast(tell,gold(X,Y)).

+cell(X,Y,empty)
  :  gold(X,Y) &
     not .desire(fetch_gold(gold(X,Y)))
  <- !remove(gold(X,Y));
     .print("The gold at ",X,",",Y," is gone. Announcing to others.");
     .broadcast(tell,picked(gold(X,Y))).

+end_of_simulation(S,R)
  <- .drop_all_desires;
     !remove(gold(_,_));
     .abolish(picked(_));
     .abolish(quadrant(X1,Y1,X2,Y2));
     .abolish(last_checked(_,_));
     -+search_gold_strategy(near_unvisited);
     -+free;
     .print("-- SMART END ",S,": ",R).


+!remove(gold(X,Y))
  <- .abolish(gold(X,Y));
     .abolish(committed_to(gold(X,Y),_,_));
     .abolish(picked(gold(X,Y)));
     .abolish(announced(gold(X,Y)));
     .abolish(allocated(gold(X,Y),_)).

@rl[atomic]
+restart
  <- .print("*** Smart miner restarting!");
     .drop_all_desires;
     !choose_goal.
