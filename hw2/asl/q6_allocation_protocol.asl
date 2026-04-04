/* gold allocation protocol — Q6 TEAM version
   Identical to adv_allocation_protocol.asl except bids are sent to "q6leader"
   and rule/function names use q6_ prefix to avoid conflicts. */

+gold(X,Y)[source(A)]
  :  A \== self
  <- !q6_calc_bid(gold(X,Y), Bid);
     .my_name(Me);
     .send(q6leader, tell, bid(gold(X,Y),Bid,Me)).

+!q6_calc_bid(gold(GX,GY), Bid)
  :  container_has_space &
     .findall(gold(X,Y),gold(X,Y),LG) &
     LG \== [] &
     pos(AgX,AgY,_) &
     q6_calc_gold_dist(LG,LD) &
     .min(LD,d(BestGoldDist,_)) &
     jia.path_length(AgX,AgY,GX,GY,GDist)
  <- GDist <= BestGoldDist;
     jia.add_fatigue(GDist,Bid).

+!q6_calc_bid(gold(GX,GY), Bid)
  :  container_has_space
  <- ?pos(AgX,AgY,_);
     jia.path_length(AgX,AgY,GX,GY,GDist);
     jia.add_fatigue(GDist,Bid).

+!q6_calc_bid(_, 10000).
-!q6_calc_bid(_, 11000).

q6_calc_gold_dist([],[]) :- true.
q6_calc_gold_dist([gold(GX,GY)|R],[d(D,gold(GX,GY))|RD])
  :- pos(AgX,AgY,_) &
     jia.path_length(AgX,AgY,GX,GY,D) &
     q6_calc_gold_dist(R,RD).

@q6palloc_full[atomic]
+allocated(Gold,Me)[source(q6leader)]
  :  .my_name(Me) & not container_has_space
  <- .abolish(allocated(Gold,Me));
     .broadcast(tell,Gold).

@q6palloc_overload[atomic]
+allocated(Gold,Me)
  :  .my_name(Me) &
     .findall(G,allocated(G,Me),LAlloc) &
     .length(LAlloc,S) & my_capacity(Cap) & S > Cap+1
  <- q6_calc_gold_dist(LAlloc,LD);
     .sort(LD,LDS);
     .length(LD,LDL);
     .nth(LDL-1,LDS,d(_,GD1));
     .nth(LDL-2,LDS,d(_,GD2));
     .abolish(allocated(GD1,Me));
     .abolish(allocated(GD2,Me));
     .broadcast(tell,GD1);
     .broadcast(tell,GD2);
     !choose_goal.

@q6palloc_assigned[atomic]
+allocated(Gold,Me)[source(q6leader)]
  :  .my_name(Me)
  <- .print("Gold ",Gold," allocated to me.");
     !choose_goal.
