// titan.asl

/* =========================================================
   RULES & MATH
========================================================= */
go_depot :- carrying_gold(3).

// THE SAFE TIME HACK: 70 extra steps of mining compared to the dummy!
go_depot :- carrying_gold(N) & N > 0 & pos(_,_,Step) & steps(_,NSteps) & Step+130 > NSteps.

// Slightly wider exploration radius (26 instead of 20) to find map corners faster
random_pos(X,Y) :-
   pos(AgX,AgY,_) &
   jia.random(RX,26)   & X = (RX-13)+AgX & X > 0 &
   jia.random(RY,26,5) & Y = (RY-13)+AgY &
   not jia.obstacle(X,Y).

/* =========================================================
   CORE MOVEMENT LOGIC (Evaluated top-to-bottom)
========================================================= */

/* -- 1. Pick Gold -- */
+pos(X,Y,_) : cell(X,Y,gold) & carrying_gold(N) & N < 3
  <- do(pick);
     .abolish(team_gold(_,_));   // Clear team targets, we have our own now!
     .abolish(explore_pos(_,_)); 
     -+mine_target(X,Y).         // Lock this in as our personal gold vein

/* -- 2. Adjacent Gold -- */
+pos(X,Y,_) : cell(GX,GY,gold) & carrying_gold(N) & N < 3
  <- jia.direction(X, Y, GX, GY, D);
     do(D).

/* -- 3. At Depot -- */
+pos(X,Y,_) : go_depot & depot(_,X,Y)
  <- do(drop).

/* -- 4. Drive-By Broadcast: See gold while full -> Tell the team! -- */
+pos(X,Y,_) : go_depot & depot(_,DX,DY) & cell(GX,GY,gold) & not broadcasted(GX,GY)
  <- .broadcast(tell, team_gold(GX,GY));
     +broadcasted(GX,GY);
     jia.direction(X, Y, DX, DY, D);
     do(D).

/* -- 5. Move to Depot (Normal) -- */
+pos(X,Y,_) : go_depot & depot(_,DX,DY)
  <- jia.direction(X, Y, DX, DY, D);
     do(D).

/* -- 6. Return to Personal Gold (Arrived or Blocked) -- */
+pos(X,Y,_) : mine_target(MX,MY) & jia.direction(X, Y, MX, MY, skip)
  <- .abolish(mine_target(MX,MY));
     !define_new_pos.

/* -- 7. Return to Personal Gold (Moving) -- */
+pos(X,Y,_) : mine_target(MX,MY) & jia.direction(X, Y, MX, MY, D)
  <- do(D).

/* -- 8. Swarm to Team Gold (Arrived or Blocked) -- */
+pos(X,Y,_) : team_gold(TX,TY) & jia.direction(X, Y, TX, TY, skip)
  <- .abolish(team_gold(TX,TY));
     !define_new_pos.

/* -- 9. Swarm to Team Gold (Moving) -- */
+pos(X,Y,_) : team_gold(TX,TY) & jia.direction(X, Y, TX, TY, D)
  <- do(D).

/* -- 10. Explore Randomly (Arrived or Blocked) -- */
+pos(X,Y,_) : explore_pos(EX,EY) & jia.direction(X, Y, EX, EY, skip)
  <- !define_new_pos.

/* -- 11. Explore Randomly (Moving) -- */
+pos(X,Y,_) : explore_pos(EX,EY) & jia.direction(X, Y, EX, EY, D)
  <- do(D).

/* -- 12. Default Catch-All -- */
+pos(_,_,_) <- !define_new_pos.

/* =========================================================
   HELPERS & MESSAGE HANDLERS
========================================================= */

+!define_new_pos
  <- ?pos(X,Y,_);
     ?random_pos(NX,NY);
     -+explore_pos(NX,NY);
     jia.direction(X, Y, NX, NY, D);
     do(D).

// Accept a team coordinate ONLY if we don't already have personal gold to mine
+team_gold(X,Y)[source(Ag)] : not mine_target(_,_)
  <- +team_gold(X,Y).

// Otherwise, ignore the message to stay focused
+team_gold(X,Y)[source(Ag)] <- true.