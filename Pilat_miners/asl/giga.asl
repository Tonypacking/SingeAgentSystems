// giga.asl
// A surgically optimized version of the dummy strategy.

/* -- RULES & MATH -- */
go_depot :- carrying_gold(3).

// HUGE ADVANTAGE: 120 more active mining steps than the dummy!
go_depot :- carrying_gold(N) & N > 0 & 
            pos(_,_,Step) & steps(_,NSteps) & 
            Step+80 > NSteps.

// Wider exploration to avoid getting stuck in small loops
random_pos(X,Y) :-
   pos(AgX,AgY,_) &
   jia.random(RX,50) & X = (RX-25)+AgX & X > 0 &
   jia.random(RY,50) & Y = (RY-25)+AgY & Y > 0 &
   not jia.obstacle(X,Y).

/* -- CORE MOVEMENT -- */

// 1. Pick gold & remember exactly where we are
+pos(X,Y,_) : cell(X,Y,gold) & carrying_gold(N) & N < 3
  <- do(pick);
     -+back_pos(X,Y).

// 2. Step to adjacent gold
+pos(X,Y,_) : cell(GX,GY,gold) & carrying_gold(N) & N < 3
  <- jia.direction(X, Y, GX, GY, D);
     do(D).

// 3. At depot (SILENT - no prints!)
+pos(X,Y,_) : go_depot & depot(_,X,Y)
  <- do(drop).

// 4. Move to depot
+pos(X,Y,_) : go_depot & depot(_,DX,DY)
  <- jia.direction(X, Y, DX, DY, D);
     do(D).

// 5. Arrived at previous gold spot or path blocked -> find new spot
+pos(X,Y,_) : back_pos(X,Y) | (back_pos(BX,BY) & jia.direction(X, Y, BX, BY, skip))
  <- !define_new_pos.

// 6. Return to previous gold spot
+pos(X,Y,_) : back_pos(BX,BY) & jia.direction(X, Y, BX, BY, D)
  <- do(D).

// 7. Default explore
+pos(_,_,_)
  <- !define_new_pos.

/* -- HELPERS -- */
+!define_new_pos
  <- ?pos(X,Y,_);
     ?random_pos(NX,NY);
     -+back_pos(NX,NY); // Treat exploration target as our back_pos
     jia.direction(X, Y, NX, NY, D);
     do(D).