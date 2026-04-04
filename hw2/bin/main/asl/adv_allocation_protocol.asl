/* gold allocation protocol — ADV TEAM version
   Identical to allocation_protocol.asl except bids are sent to "advleader" */

+gold(X,Y)[source(A)]
  :  A \== self
  <- !adv_calc_bid(gold(X,Y), Bid);
     .my_name(Me);
     .send(advleader,tell,bid(gold(X,Y),Bid,Me)).

+!adv_calc_bid(gold(GX,GY), Bid)
  :  container_has_space &
     .findall(gold(X,Y),gold(X,Y),LG) &
     LG \== [] &
     pos(AgX,AgY,_) &
     adv_calc_gold_distance(LG,LD) &
     .min(LD,d(BestGoldDist,_)) &
     jia.path_length(AgX,AgY,GX,GY,GDist)
  <- GDist <= BestGoldDist;
     jia.add_fatigue(GDist,Bid).

+!adv_calc_bid(gold(GX,GY), Bid)
  :  container_has_space
  <- ?pos(AgX,AgY,_);
     jia.path_length(AgX,AgY,GX,GY,GDist);
     jia.add_fatigue(GDist,Bid).

+!adv_calc_bid(_, 10000).
-!adv_calc_bid(_, 11000).

adv_calc_gold_distance([],[]) :- true.
adv_calc_gold_distance([gold(GX,GY)|R],[d(D,gold(GX,GY))|RD])
  :- pos(AgX,AgY,_) &
     jia.path_length(AgX,AgY,GX,GY,D) &
     adv_calc_gold_distance(R,RD).

@advpalloc2[atomic]
+allocated(Gold,Me)[source(advleader)]
  :  .my_name(Me) & not container_has_space
  <- .abolish(allocated(Gold,Me));
     .broadcast(tell,Gold).

@advpalloc3[atomic]
+allocated(Gold,Me)
  :  .my_name(Me) &
     .findall(G,allocated(G,Me),LAlloc) &
     .length(LAlloc,S) & my_capacity(Cap) & S > Cap+1
  <- ?adv_calc_gold_distance(LAlloc,LD);
     .sort(LD,LDS);
     .length(LD,LDL);
     .nth(LDL-1,LDS,d(_,GD1));
     .nth(LDL-2,LDS,d(_,GD2));
     .abolish(allocated(GD1,Me));
     .abolish(allocated(GD2,Me));
     .broadcast(tell,GD1);
     .broadcast(tell,GD2);
     !choose_goal.

@advpalloc4[atomic]
+allocated(Gold,Me)[source(advleader)]
  :  .my_name(Me)
  <- .print("Gold ",Gold," allocated to me.");
     !choose_goal.
