// stupidminer.asl

/* -- useful rules -- */
go_depot :- carrying_gold(3).
go_depot :- carrying_gold(N) & N > 0 & pos(_,_,Step) & steps(_,NSteps) & Step+200 > NSteps.

// A slightly wider search radius to spread out fast
random_pos(X,Y) :-
   pos(AgX,AgY,_) &
   jia.random(RX,30)   & X = (RX-15)+AgX & X > 0 &
   jia.random(RY,30,5) & Y = (RY-15)+AgY & Y > 0 &
   not jia.obstacle(X,Y).

/* -- Reporting (No action cost) -- */
+cell(GX,GY,gold) : carrying_gold(3) & not reported(GX,GY)
  <- .send(stupidleader, tell, found_gold(GX,GY));
     +reported(GX,GY).


/* =========================================================
   CORE MOVEMENT LOGIC
========================================================= */

/* -- 1. Pick gold & REMEMBER THE SPOT -- */
+pos(X,Y,_) : cell(X,Y,gold) & carrying_gold(N) & N < 3
  <- do(pick);
     .abolish(target(_,_)); 
     -+last_gold(X,Y). // Stubbornly remember this vein!

/* -- 2. Adjacent gold -- */
+pos(X,Y,_) : cell(GX,GY,gold) & carrying_gold(N) & N < 3
  <- jia.direction(X, Y, GX, GY, D);
     do(D).

/* -- 3. At depot (DO NOT FORGET last_gold) -- */
+pos(X,Y,_) : go_depot & depot(_,X,Y)
  <- do(drop). 

/* -- 4. Move to depot -- */
+pos(X,Y,_) : go_depot & depot(_,DX,DY)
  <- jia.direction(X, Y, DX, DY, D);
     do(D).

/* -- 5. Return to last known gold (The Anti-Amnesia Rule) -- */
+pos(X,Y,_) : not go_depot & last_gold(LX,LY)
  <- jia.direction(X, Y, LX, LY, D);
     !execute_return(D).

/* -- 6. Follow Target from Leader -- */
+pos(X,Y,_) : not go_depot & target(TX,TY)
  <- jia.direction(X, Y, TX, TY, D);
     !execute_target(D).

/* -- 7. Default: Explore randomly -- */
+pos(_,_,_)
  <- !define_new_pos.


/* =========================================================
   EXECUTION HELPERS
========================================================= */

// If we got back to our vein and it's empty -> Ask leader for new target
+!execute_return(skip)
  <- .abolish(last_gold(_,_));
     .send(stupidleader, achieve, get_target);
     !define_new_pos. // Keep moving while waiting for leader
+!execute_return(D)
  <- do(D).

// If leader target is empty -> explore
+!execute_target(skip)
  <- .abolish(target(_,_));
     !define_new_pos.
+!execute_target(D)
  <- do(D).

+!define_new_pos
  <- ?pos(X,Y,_);
     ?random_pos(NX,NY);
     -+target(NX,NY); // Treat exploration as a temporary target
     jia.direction(X, Y, NX, NY, D);
     do(D).

/* -- Message handling -- */
+target(X,Y)[source(stupidleader)] 
  <- .abolish(target(_,_)); 
     +target(X,Y).
+explore[source(stupidleader)] 
  <- true.