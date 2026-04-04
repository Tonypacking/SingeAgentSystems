// apex2.asl — smarter apex: prefers least-visited tiles over random

/* -- RULES -- */
go_depot :- carrying_gold(3).
go_depot :- carrying_gold(N) & N > 0 &
            pos(_,_,Step) & steps(_,NSteps) &
            Step+120 > NSteps.

/* -- CORE MOVEMENT -- */

// 1. Pick gold on current cell
+pos(X,Y,_) : cell(X,Y,gold) & carrying_gold(N) & N < 3
  <- do(pick);
     -+back_pos(X,Y).

// 2. Step toward adjacent gold
+pos(X,Y,_) : cell(GX,GY,gold) & carrying_gold(N) & N < 3
  <- jia.direction(X,Y,GX,GY,D);
     do(D).

// 3. At depot — drop
+pos(X,Y,_) : go_depot & depot(_,X,Y)
  <- do(drop).

// 4. Heading to depot
+pos(X,Y,_) : go_depot & depot(_,DX,DY)
  <- jia.direction(X,Y,DX,DY,D);
     do(D).

// 5. Arrived at back_pos or path blocked — explore least-visited
+pos(X,Y,_) : back_pos(X,Y)
  <- !explore.
+pos(X,Y,_) : back_pos(BX,BY) & jia.direction(X,Y,BX,BY,skip)
  <- !explore.

// 6. Moving toward back_pos
+pos(X,Y,_) : back_pos(BX,BY) & jia.direction(X,Y,BX,BY,D)
  <- do(D).

// 7. Default — explore
+pos(_,_,_)
  <- !explore.

/* -- EXPLORATION: prefer least-visited tiles -- */

// Use built-in least-visited tracker (requires LocalMinerArch)
+!explore : pos(X,Y,_) & jia.near_least_visited(X,Y,TX,TY)
  <- -+back_pos(TX,TY);
     jia.direction(X,Y,TX,TY,D);
     do(D).

// Fallback: wider random if near_least_visited fails
+!explore
  <- ?pos(X,Y,_);
     jia.random(RX,40); NX = (RX-20)+X;
     jia.random(RY,40); NY = (RY-20)+Y;
     -+back_pos(NX,NY);
     jia.direction(X,Y,NX,NY,D);
     do(D).

-!explore <- do(skip).
