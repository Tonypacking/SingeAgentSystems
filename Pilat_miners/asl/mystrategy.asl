// mystrategy.asl

/* =========================================================
   RULES & MATH
========================================================= */
// 1. Go to depot if full
go_depot :- carrying_gold(3).

// 2. THE TIME HACK: Calculate Manhattan distance to depot.
// Only go home when we absolutely have to, giving us way more mining time than the dummy!
go_depot :- carrying_gold(N) & N > 0 & 
            pos(X,Y,Step) & steps(_,NSteps) & 
            depot(_,DX,DY) & 
            (Step + math.abs(X - DX) + math.abs(Y - DY) + 40) > NSteps.

// 3. RAYCAST EXPLORATION: Pick a point far away (50 radius instead of dummy's 10) 
// to prevent walking in circles and cover the whole map.
random_pos(X,Y) :-
   pos(AgX,AgY,_) &
   jia.random(RX,100)  & X = (RX-50)+AgX & X > 0 &
   jia.random(RY,100,5) & Y = (RY-50)+AgY & Y > 0 &
   not jia.obstacle(X,Y).

/* =========================================================
   CORE MOVEMENT LOGIC (Evaluated top-to-bottom every step)
========================================================= */

/* -- 1. Pick gold -- */
+pos(X,Y,_) : cell(X,Y,gold) & carrying_gold(N) & N < 3
  <- do(pick);
     .abolish(target(_,_)). // Stop exploring, we hit a cluster!

/* -- 2. Adjacent gold -> move to it -- */
+pos(X,Y,_) : cell(GX,GY,gold) & carrying_gold(N) & N < 3
  <- jia.direction(X, Y, GX, GY, D);
     do(D).

/* -- 3. At depot -> Drop gold and get new far target -- */
+pos(X,Y,_) : go_depot & depot(_,X,Y)
  <- do(drop);
     .abolish(target(_,_));
     !define_new_pos.

/* -- 4. Move to depot -- */
+pos(X,Y,_) : go_depot & depot(_,DX,DY)
  <- jia.direction(X, Y, DX, DY, D);
     do(D).

/* -- 5. Follow Exploration Target in a straight line -- */
+pos(X,Y,_) : not go_depot & target(TX,TY)
  <- jia.direction(X, Y, TX, TY, D);
     !execute_target(D).

/* -- 6. Default: Need new target -- */
+pos(_,_,_)
  <- !define_new_pos.


/* =========================================================
   EXECUTION HELPERS
========================================================= */

// If we hit a wall or arrived at our random point, pick a new one
+!execute_target(skip)
  <- .abolish(target(_,_));
     !define_new_pos.
     
+!execute_target(D)
  <- do(D).

+!define_new_pos
  <- ?pos(X,Y,_);
     ?random_pos(NX,NY);
     -+target(NX,NY);
     jia.direction(X, Y, NX, NY, D);
     do(D).