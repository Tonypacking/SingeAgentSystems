/* smart gold allocation protocol */

+gold(X,Y)[source(A)]
  :  A \== self
  <- !calc_bid(gold(X,Y), Bid);
     .my_name(Me);
     .send(smartleader,tell,bid(gold(X,Y),Bid,Me)).

+!calc_bid(gold(GX,GY), Bid)
  :  container_has_space &
     .findall(gold(X,Y),gold(X,Y),LG) &
     LG \== [] &
     pos(AgX,AgY,_) &
     calc_gold_distance(LG,LD) &
     .min(LD,d(BestGoldDist,_)) &
     jia.path_length(AgX,AgY,GX,GY,GDist) &
     .my_name(Me) &
     .count(allocated(_,Me),AllocN) &
     carrying_gold(NG) &
     sector_penalty(gold(GX,GY),SP) &
     cargo_penalty(NG,GDist,CP)
  <- GDist <= BestGoldDist + 2;
     jia.add_fatigue(GDist,NG,FatDist);
     Bid = FatDist + SP + CP + (AllocN * 12).

+!calc_bid(gold(GX,GY), Bid)
  :  container_has_space &
     .findall(gold(X,Y),gold(X,Y),LG) &
     LG == [] &
     pos(AgX,AgY,_) &
     jia.path_length(AgX,AgY,GX,GY,GDist) &
     .my_name(Me) &
     .count(allocated(_,Me),AllocN) &
     carrying_gold(NG) &
     sector_penalty(gold(GX,GY),SP) &
     cargo_penalty(NG,GDist,CP)
  <- jia.add_fatigue(GDist,NG,FatDist);
     Bid = FatDist + SP + CP + (AllocN * 12).

+!calc_bid(_, 10000).
-!calc_bid(_, 11000).

sector_penalty(G,0) :- gold_in_sector(G).
sector_penalty(_,8).

cargo_penalty(0,_,0).
cargo_penalty(1,_,1).
cargo_penalty(2,D,500) :- D > 8.
cargo_penalty(2,_,6).

calc_gold_distance([],[]) :- true.
calc_gold_distance([gold(GX,GY)|R],[d(D,gold(GX,GY))|RD])
  :- pos(AgX,AgY,_) &
     jia.path_length(AgX,AgY,GX,GY,D) &
     calc_gold_distance(R,RD).

@palloc2[atomic]
+allocated(Gold,Me)[source(smartleader)]
  :  .my_name(Me) &
     not container_has_space
  <- .print("I can not handle ",Gold," anymore! Re-announcing.");
     .abolish(allocated(Gold,Me));
     .broadcast(tell,Gold).

@palloc3[atomic]
+allocated(Gold,Me)
  :  .my_name(Me) &
     .findall(G,allocated(G,Me),LAlloc) &
     .length(LAlloc,S) & my_capacity(Cap) & S > Cap+1
  <- ?calc_gold_distance(LAlloc,LD);
     .sort(LD,LDS);
     .length(LD,LDL);
     .nth(LDL-1,LDS,d(_,GDiscarded1));
     .nth(LDL-2,LDS,d(_,GDiscarded2));
     .print("Too many allocations ",LDS,", discarding ",GDiscarded1," and ",GDiscarded2);
     .abolish(allocated(GDiscarded1,Me));
     .abolish(allocated(GDiscarded2,Me));
     .broadcast(tell,GDiscarded1);
     .broadcast(tell,GDiscarded2);
     !choose_goal.

@palloc4[atomic]
+allocated(Gold,Me)[source(smartleader)]
  :  .my_name(Me)
  <- .print("Gold ",Gold," allocated to me. Re-deciding.");
     !choose_goal.
