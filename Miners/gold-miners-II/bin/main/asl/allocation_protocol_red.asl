/* gold allocation protocol — RED TEAM version
   Identical to allocation_protocol.asl except bids are sent to "rleader" */

// someone else sent me a gold location, send a bid
+gold(X,Y)[source(A)]
  :  A \== self
  <- !calc_bid(gold(X,Y), Bid);
     .my_name(Me);
     .send(rleader,tell,bid(gold(X,Y),Bid,Me)).

// bid in case I have space and not known golds: the distance to gold
+!calc_bid(gold(GX,GY), Bid)
  :  container_has_space &
     .findall(gold(X,Y),gold(X,Y),LG) &
     LG \== [] &
     pos(AgX,AgY,_) &
     calc_gold_distance(LG,LD) &
     .min(LD,d(BestGoldDist,BestGold)) &
     jia.path_length(AgX,AgY,GX,GY,GDist)
  <- GDist <= BestGoldDist;
     jia.add_fatigue(GDist,Bid).

+!calc_bid(gold(GX,GY), Bid)
  :  container_has_space
  <- ?pos(AgX,AgY,_);
     jia.path_length(AgX,AgY,GX,GY,GDist);
     jia.add_fatigue(GDist,Bid).

+!calc_bid(_, 10000).
-!calc_bid(_, 11000).

calc_gold_distance([],[]) :- true.
calc_gold_distance([gold(GX,GY)|R],[d(D,gold(GX,GY))|RD])
  :- pos(AgX,AgY,_) &
     jia.path_length(AgX,AgY,GX,GY,D) &
     calc_gold_distance(R,RD).


// allocated to me but no space — re-announce
@rpalloc2[atomic]
+allocated(Gold,Me)[source(rleader)]
  :  .my_name(Me) & not container_has_space
  <- .abolish(allocated(Gold,Me));
     .broadcast(tell,Gold).

// too many allocations — discard the worst
@rpalloc3[atomic]
+allocated(Gold,Me)
  :  .my_name(Me) &
     .findall(G,allocated(G,Me),LAlloc) &
     .length(LAlloc,S) & my_capacity(Cap) & S > Cap+1
  <- ?calc_gold_distance(LAlloc,LD);
     .sort(LD,LDS);
     .length(LD,LDL);
     .nth(LDL-1,LDS,d(_,GD1));
     .nth(LDL-2,LDS,d(_,GD2));
     .abolish(allocated(GD1,Me));
     .abolish(allocated(GD2,Me));
     .broadcast(tell,GD1);
     .broadcast(tell,GD2);
     !choose_goal.

// allocated to me — reconsider
@rpalloc4[atomic]
+allocated(Gold,Me)[source(rleader)]
  :  .my_name(Me)
  <- .print("Gold ",Gold," allocated to me.");
     !choose_goal.
