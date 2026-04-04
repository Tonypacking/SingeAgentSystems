// world12killer.asl

/* -- RULES & MATH -- */
go_depot :- carrying_gold(3).

// THE GOLDILOCKS HACK FOR WORLD 12: 
// 120 steps was too risky for the maze. 200 steps (dummy) is too safe. 
// 180 gives us exactly 20 more active mining steps than the dummy while ensuring a safe return.
go_depot :- carrying_gold(N) & N > 0 & 
            pos(_,_,Step) & steps(_,NSteps) & 
            Step+180 > NSteps.

// Standard, crash-proof exploration radius
random_pos(X,Y) :-
   pos(AgX,AgY,_) &
   jia.random(RX,20)   & X = (RX-10)+AgX & X > 0 &
   jia.random(RY,20,5) & Y = (RY-10)+AgY &
   not jia.obstacle(X,Y).

/* -- CORE MOVEMENT LOGIC -- */

// 1. Pick gold and remember the spot
+pos(X,Y,_) : cell(X,Y,gold) & carrying_gold(N) & N < 3
  <- do(pick);
     -+back_pos(X,Y).

// 2. Step to adjacent gold
+pos(X,Y,_) : cell(GX,GY,gold) & carrying_gold(N) & N < 3
  <- jia.direction(X, Y, GX, GY, D);
     do(D).

// 3. At depot (SILENT - no .print lag)
+pos(X,Y,_) : go_depot & depot(_,X,Y)
  <- do(drop).

// 4. Move to depot safely through the maze
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
     -+back_pos(NX,NY);
     jia.direction(X, Y, NX, NY, D);
     do(D).