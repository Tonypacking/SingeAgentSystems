// apex_prime.asl

/* -- RULES -- */
go_depot :- carrying_gold(3).
go_depot :- carrying_gold(N) & N > 0 & pos(_,_,S) & steps(_,MS) & S+120 > MS.

random_pos(X,Y) :-
   pos(AgX,AgY,_) & jia.random(RX,20) & X=(RX-10)+AgX & X>0 &
   jia.random(RY,20,5) & Y=(RY-10)+AgY & not jia.obstacle(X,Y).

/* -- LOGIC -- */

// 1. Pick gold and update back_pos
+pos(X,Y,_) : cell(X,Y,gold) & carrying_gold(N) & N < 3
  <- do(pick); -+back_pos(X,Y); .abolish(target(_,_)).

// 2. Move to adjacent gold
+pos(X,Y,_) : cell(GX,GY,gold) & carrying_gold(N) & N < 3
  <- jia.direction(X,Y,GX,GY,D); do(D).

// 3. FULL BAG + SEES GOLD -> Report to Leader!
+cell(GX,GY,gold) : carrying_gold(3) & not reported(GX,GY)
  <- .send(apex_leader, tell, found_gold(GX,GY)); +reported(GX,GY).

// 4. Depot Logic
+pos(X,Y,_) : go_depot & depot(_,X,Y) <- do(drop).
+pos(X,Y,_) : go_depot & depot(_,DX,DY) 
  <- jia.direction(X,Y,DX,DY,D); do(D).

// 5. If "back_pos" is empty/blocked -> Ask Leader for a "Job"
+pos(X,Y,_) : back_pos(X,Y) | (back_pos(BX,BY) & jia.direction(X,Y,BX,BY,skip))
  <- -back_pos(_,_); .send(apex_leader, achieve, get_job); !explore.

// 6. Go to Personal Gold
+pos(X,Y,_) : back_pos(BX,BY) & jia.direction(X,Y,BX,BY,D) <- do(D).

// 7. Go to Leader's assigned Target
+pos(X,Y,_) : target(TX,TY) & jia.direction(X,Y,TX,TY,D) <- do(D).

// 8. Default
+pos(_,_,_) <- !explore.

+!explore <- ?pos(X,Y,_); ?random_pos(NX,NY); jia.direction(X,Y,NX,NY,D); do(D).

/* -- MESSAGES -- */
+target(X,Y)[source(apex_leader)] <- -target(_,_); +target(X,Y).
+explore[source(apex_leader)] <- true.