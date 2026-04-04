// nemesisminer.asl

/* -- RULES & MATH -- */
go_depot :- carrying_gold(3).
go_depot :- carrying_gold(N) & N > 0 & pos(_,_,Step) & steps(_,NSteps) & Step+180 > NSteps.

random_pos(X,Y) :-
   pos(AgX,AgY,_) &
   jia.random(RX,30)   & X = (RX-15)+AgX & X > 0 & // Slightly wider spread than dummy
   jia.random(RY,30,5) & Y = (RY-15)+AgY &
   not jia.obstacle(X,Y).

/* -- CORE MOVEMENT LOGIC -- */

// 1. Pick gold & remember personal spot
+pos(X,Y,_) : cell(X,Y,gold) & carrying_gold(N) & N < 3
  <- do(pick);
     .abolish(target(_,_)); 
     -+back_pos(X,Y).

// 2. Step to adjacent gold
+pos(X,Y,_) : cell(GX,GY,gold) & carrying_gold(N) & N < 3
  <- jia.direction(X, Y, GX, GY, D);
     do(D).

// 3. At depot (SILENT)
+pos(X,Y,_) : go_depot & depot(_,X,Y)
  <- do(drop).

// 4. THE RELAY: Heading to depot, but I see more gold! -> Tell Leader, then keep walking
+pos(X,Y,_) : go_depot & cell(GX,GY,gold) & not reported(GX,GY) & depot(_,DX,DY)
  <- .send(nemesisleader, tell, found_vein(GX,GY));
     +reported(GX,GY);
     jia.direction(X, Y, DX, DY, D);
     do(D).

// 5. Move to depot (Normal)
+pos(X,Y,_) : go_depot & depot(_,DX,DY)
  <- jia.direction(X, Y, DX, DY, D);
     do(D).

// 6. Personal gold empty/blocked -> Ask Leader for work!
+pos(X,Y,_) : back_pos(X,Y) | (back_pos(BX,BY) & jia.direction(X,Y,BX,BY,skip))
  <- .abolish(back_pos(_,_));
     .send(nemesisleader, achieve, get_target);
     !define_new_pos. // Keep moving while waiting for reply

// 7. Move to personal gold
+pos(X,Y,_) : back_pos(BX,BY) & jia.direction(X,Y,BX,BY,D)
  <- do(D).

// 8. Leader's target empty/blocked -> Ask again!
+pos(X,Y,_) : target(TX,TY) & jia.direction(X,Y,TX,TY,skip)
  <- .abolish(target(TX,TY));
     .send(nemesisleader, achieve, get_target);
     !define_new_pos.

// 9. Move to Leader's target
+pos(X,Y,_) : target(TX,TY) & jia.direction(X,Y,TX,TY,D)
  <- do(D).

// 10. Default explore
+pos(_,_,_) <- !define_new_pos.

/* -- HELPERS & MESSAGES -- */
+!define_new_pos
  <- ?pos(X,Y,_);
     ?random_pos(NX,NY);
     -+target(NX,NY); // Treat random point as temporary target
     jia.direction(X, Y, NX, NY, D);
     do(D).

+target(X,Y)[source(nemesisleader)] <- .abolish(target(_,_)); +target(X,Y).
+explore[source(nemesisleader)] <- true.