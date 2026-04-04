// skibidyminer.asl

/* -- Rules -- */
// Go to depot if full or if time is running out
go_depot :- carrying_gold(3).
go_depot :- carrying_gold(N) & N > 0 & pos(_,_,Step) & steps(_,NSteps) & Step+200 > NSteps.

/* -- Reactions to the Environment -- */

// 1. I am standing on gold, and my bag is NOT full -> Pick it up!
+pos(X,Y,_) : cell(X,Y,gold) & carrying_gold(N) & N < 3
  <- do(pick);
     -target(X,Y). // If this was my assigned target, clear it

// 2. Gold is adjacent, and my bag is NOT full -> Step towards it!
+pos(X,Y,_) : cell(GX,GY,gold) & carrying_gold(N) & N < 3
  <- jia.direction(X, Y, GX, GY, D);
     do(D).

// 3. I see gold, but my bag IS full -> Tell the leader!
+cell(GX,GY,gold) : carrying_gold(3) & not reported(GX,GY)
  <- .send(skibidyleader, tell, found_gold(GX,GY));
     +reported(GX,GY).

/* -- Depot Logic -- */

// 4. I need to go to the depot, and I am standing on it -> Drop gold and ask for new task!
+pos(X,Y,_) : go_depot & depot(_,X,Y)
  <- do(drop);
     -target(_,_); // Clear any old targets
     .send(skibidyleader, achieve, get_target).

// 5. I need to go to the depot, but I am not there yet -> Move towards it!
+pos(X,Y,_) : go_depot & depot(_,DX,DY)
  <- jia.direction(X, Y, DX, DY, D);
     do(D).

/* -- Movement & Exploration -- */

// 6. I have a target from the leader -> Move straight to it!
+pos(X,Y,_) : target(TX,TY) & not go_depot
  <- jia.direction(X, Y, TX, TY, D);
     do(D).

// 7. I have no target and don't need the depot -> Explore randomly
+pos(X,Y,_) : not target(_,_) & not go_depot
  <- !explore.

+!explore : pos(X,Y,_)
  <- jia.random(RX,20); NX = (RX-10)+X;
     jia.random(RY,20,5); NY = (RY-10)+Y;
     jia.direction(X, Y, NX, NY, D);
     do(D).

/* -- Receiving Messages from Leader -- */
+target(X,Y)[source(skibidyleader)] <- +target(X,Y).
+explore[source(skibidyleader)] <- !explore.