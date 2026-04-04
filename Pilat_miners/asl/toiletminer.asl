// toiletminer.asl

/* -- useful rules -- */
go_depot :- carrying_gold(3).
go_depot :- carrying_gold(N) & N > 0 & pos(_,_,Step) & steps(_,NSteps) & Step+200 > NSteps.

random_pos(X,Y) :-
   pos(AgX,AgY,_) &
   jia.random(RX,20)   & X = (RX-10)+AgX & X > 0 &
   jia.random(RY,20,5) & Y = (RY-10)+AgY & Y > 0 &
   not jia.obstacle(X,Y).

/* -- Reporting gold to leader (Does not consume a turn) -- */
+cell(GX,GY,gold) : carrying_gold(3) & not reported(GX,GY)
  <- .send(toiletleader, tell, found_gold(GX,GY));
     +reported(GX,GY).

/* =========================================================
   CORE MOVEMENT LOGIC (Evaluated top-to-bottom every step)
========================================================= */

/* -- 1. Pick gold -- */
+pos(X,Y,_) : cell(X,Y,gold) & carrying_gold(N) & N < 3
  <- do(pick);
     .abolish(target(_,_)); // Clear leader target if we had one
     -+back_pos(X,Y).       // Remember this cluster

/* -- 2. Adjacent gold -- */
+pos(X,Y,_) : cell(GX,GY,gold) & carrying_gold(N) & N < 3
  <- jia.direction(X, Y, GX, GY, D);
     do(D).

/* -- 3. At depot -- */
+pos(X,Y,_) : go_depot & depot(_,X,Y)
  <- do(drop);
     .abolish(target(_,_));
     .abolish(back_pos(_,_));
     .send(toiletleader, achieve, get_target).

/* -- 4. Move to depot -- */
+pos(X,Y,_) : go_depot & depot(_,DX,DY)
  <- jia.direction(X, Y, DX, DY, D);
     do(D).

/* -- 5. Follow Target from Leader -- */
+pos(X,Y,_) : not go_depot & target(TX,TY)
  <- jia.direction(X, Y, TX, TY, D);
     !execute_target(D).

/* -- 6. Follow Local Memory (Return to previous cluster) -- */
+pos(X,Y,_) : not go_depot & not target(_,_) & back_pos(BX,BY)
  <- jia.direction(X, Y, BX, BY, D);
     !execute_back(D).

/* -- 7. Default: Explore randomly -- */
+pos(_,_,_)
  <- !define_new_pos.


/* =========================================================
   SUB-GOALS AND HELPERS
========================================================= */

/* -- Execution helpers to safely handle 'skip' directions -- */
+!execute_target(skip)
  <- .abolish(target(_,_)); // Target is empty or blocked, clear it
     !define_new_pos.
+!execute_target(D)
  <- do(D).

+!execute_back(skip)
  <- .abolish(back_pos(_,_)); // Local memory cleared
     !define_new_pos.
+!execute_back(D)
  <- do(D).

/* -- Exploration Logic -- */
+!define_new_pos
  <- ?pos(X,Y,_);
     ?random_pos(NX,NY);
     -+back_pos(NX,NY);
     jia.direction(X, Y, NX, NY, D);
     do(D).

/* -- Message handling from leader -- */
+target(X,Y)[source(toiletleader)] 
  <- .abolish(target(_,_)); // Clear old targets so they don't pile up
     +target(X,Y).
+explore[source(toiletleader)] 
  <- true.