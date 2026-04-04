// omega.asl

/* =========================================================
   RULES & MATH (Copied from dummy, tweaked time limit)
========================================================= */
go_depot :- carrying_gold(3).
go_depot :- carrying_gold(N) & N > 0 & pos(_,_,Step) & steps(_,NSteps) & Step+150 > NSteps.

random_pos(X,Y) :-
   pos(AgX,AgY,_) &
   jia.random(RX,20)   & X = (RX-10)+AgX & X > 0 &
   jia.random(RY,20,5) & Y = (RY-10)+AgY &
   not jia.obstacle(X,Y).

/* =========================================================
   CORE MOVEMENT LOGIC
========================================================= */

/* -- 1. Pick gold -- */
+pos(X,Y,_)
   : cell(X,Y,gold) & carrying_gold(N) & N < 3
  <- do(pick);
     .abolish(known_gold(X,Y)); // We picked it, clear memory
     -+back_pos(X,Y).

/* -- 2. Step to adjacent gold -- */
+pos(X,Y,_)
   : cell(GX,GY,gold) & carrying_gold(N) & N < 3
  <- jia.direction(X, Y, GX, GY, D);
     do(D).

/* -- 3. At depot -- */
+pos(X,Y,_)
   : go_depot & depot(_,X,Y)
  <- do(drop).

/* -- 4. Move to depot WITH PHOTOGRAPHIC MEMORY -- */
// If we are heading home and see gold, remember it for later!
+pos(X,Y,_)
   : go_depot & depot(_,DX,DY) & cell(GX,GY,gold)
  <- -+known_gold(GX,GY); 
     jia.direction(X, Y, DX, DY, D);
     do(D).

/* -- 5. Move to depot (Normal) -- */
+pos(X,Y,_)
   : go_depot & depot(_,DX,DY)
  <- jia.direction(X, Y, DX, DY, D);
     do(D).

/* -- 6. SMART MEMORY RECALL -- */
// If we remembered gold, but someone else took it (skip), forget it.
+pos(X,Y,_)
   : known_gold(KX,KY) & jia.direction(X,Y,KX,KY,skip)
  <- .abolish(known_gold(KX,KY));
     !define_new_pos.

// Walk back to the gold we remembered!
+pos(X,Y,_)
   : known_gold(KX,KY) & jia.direction(X,Y,KX,KY,D)
  <- do(D).

/* -- 7. Go to back_pos (Dummy's original fallback) -- */
+pos(X,Y,_)
   : back_pos(X,Y) | (back_pos(BX,BY) & jia.direction(X, Y, BX, BY, skip))
  <- !define_new_pos.

+pos(X,Y,_)
   : back_pos(BX,BY) & jia.direction(X, Y, BX, BY, D)
  <- do(D).

/* -- 8. Random move -- */
+pos(_,_,_)
   <- !define_new_pos.

+!define_new_pos
   <- ?pos(X,Y,_);
      ?random_pos(NX,NY);
      -+back_pos(NX,NY);
      jia.direction(X, Y, NX, NY, D);
      do(D).