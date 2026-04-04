// toiletminer.asl

/* -- Rules -- */
go_depot :- carrying_gold(3).
go_depot :- carrying_gold(N) & N > 0 & pos(_,_,Step) & steps(_,NSteps) & Step+200 > NSteps.

// Find a free random location (wider search radius than dummy)
random_pos(X,Y) :-
   pos(AgX,AgY,_) &
   jia.random(RX,30)   & X = (RX-15)+AgX & X > 0 &
   jia.random(RY,30,5) & Y = (RY-15)+AgY & Y > 0 &
   not jia.obstacle(X,Y).

/* -- Core Logic (Highest to Lowest Priority) -- */

// 1. Standing on gold -> Pick it up
+pos(X,Y,_) : cell(X,Y,gold) & carrying_gold(N) & N < 3
  <- do(pick);
     -+back_pos(X,Y); // Remember this spot, gold spawns in clusters!
     -target(X,Y).    // Clear target if we had one

// 2. Gold is adjacent -> Move to it
+pos(X,Y,_) : cell(GX,GY,gold) & carrying_gold(N) & N < 3
  <- jia.direction(X, Y, GX, GY, D); 
     do(D).

// 3. I see gold, but my bag is full -> Tell Leader
+cell(GX,GY,gold) : carrying_gold(3) & not reported(GX,GY)
  <- .send(toiletleader, tell, found_gold(GX,GY));
     +reported(GX,GY).

// 4. At Depot -> Drop gold and ask Leader for task
+pos(X,Y,_) : go_depot & depot(_,X,Y)
  <- do(drop);
     -target(_,_); 
     .send(toiletleader, achieve, get_target).

// 5. Need Depot -> Go to it
+pos(X,Y,_) : go_depot & depot(_,DX,DY)
  <- jia.direction(X, Y, DX, DY, D); 
     do(D).

// 6. Have Leader Target but arrived/stuck -> Clear it
+pos(X,Y,_) : target(TX,TY) & jia.direction(X, Y, TX, TY, skip)
  <- -target(TX,TY); 
     !define_new_pos.

// 7. Have Leader Target -> Move to it
+pos(X,Y,_) : target(TX,TY) & jia.direction(X, Y, TX, TY, D)
  <- do(D).

// 8. Have Local Memory (back_pos) but arrived/stuck -> Clear it
+pos(X,Y,_) : back_pos(BX,BY) & jia.direction(X, Y, BX, BY, skip)
  <- !define_new_pos.

// 9. Have Local Memory (back_pos) -> Move to it
+pos(X,Y,_) : back_pos(BX,BY) & jia.direction(X, Y, BX, BY, D)
  <- do(D).

// 10. Default -> Explore
+pos(_,_,_) <- !define_new_pos.

+!define_new_pos
  <- ?pos(X,Y,_);
     ?random_pos(NX,NY);
     -+back_pos(NX,NY);
     jia.direction(X, Y, NX, NY, D);
     do(D).

/* -- Message Handlers -- */
+target(X,Y)[source(toiletleader)] <- +target(X,Y); -back_pos(_,_).
+explore[source(toiletleader)] <- true.