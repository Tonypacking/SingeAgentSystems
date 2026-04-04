// hyperionminer.asl

/* -- RULES & MATH -- */
go_depot :- carrying_gold(3).
go_depot :- carrying_gold(N) & N > 0 & pos(_,_,Step) & steps(_,NSteps) & Step+120 > NSteps.

random_pos(X,Y) :-
   pos(AgX,AgY,_) &
   jia.random(RX,20)   & X = (RX-10)+AgX & X > 0 &
   jia.random(RY,20,5) & Y = (RY-10)+AgY &
   not jia.obstacle(X,Y).

/* -- CORE MOVEMENT LOGIC -- */

// 1. Pick gold & remember personal spot
+pos(X,Y,_) : cell(X,Y,gold) & carrying_gold(N) & N < 3
  <- do(pick);
     .abolish(target(_,_)); 
     -+back_pos(X,Y).

// 2. Step to adjacent gold
+pos(X,Y,_) : cell(GX,GY,gold) & carrying_gold(N) & N < 3
  <- jia.direction(X, Y, GX, GY, D);
     do(D).

// 3. Bag is full and I see extra gold -> Silently text the Leader
+cell(GX,GY,gold) : carrying_gold(3) & not reported(GX,GY)
  <- .send(hyperionleader, tell, found_gold(GX,GY));
     +reported(GX,GY).

// 4. At depot
+pos(X,Y,_) : go_depot & depot(_,X,Y)
  <- do(drop).

// 5. Move to depot
+pos(X,Y,_) : go_depot & depot(_,DX,DY)
  <- jia.direction(X, Y, DX, DY, D);
     do(D).

// 6. Personal gold is empty or blocked -> Ask Leader for work!
+pos(X,Y,_) : back_pos(BX,BY) & jia.direction(X, Y, BX, BY, skip)
  <- .abolish(back_pos(BX,BY));
     .send(hyperionleader, achieve, get_target);
     !define_new_pos. // Keep exploring while waiting for leader to reply

// 7. Move to personal gold
+pos(X,Y,_) : back_pos(BX,BY) & jia.direction(X, Y, BX, BY, D)
  <- do(D).

// 8. Leader's target is empty or blocked -> Ask Leader again!
+pos(X,Y,_) : target(TX,TY) & jia.direction(X, Y, TX, TY, skip)
  <- .abolish(target(TX,TY));
     .send(hyperionleader, achieve, get_target);
     !define_new_pos.

// 9. Move to Leader's target
+pos(X,Y,_) : target(TX,TY) & jia.direction(X, Y, TX, TY, D)
  <- do(D).

// 10. Default explore
+pos(_,_,_) <- !define_new_pos.

/* -- HELPERS & MESSAGES -- */
+!define_new_pos
  <- ?pos(X,Y,_);
     ?random_pos(NX,NY);
     -+target(NX,NY); // Use target as a temporary exploration point
     jia.direction(X, Y, NX, NY, D);
     do(D).

// When leader sends a target, override our temporary exploration point
+target(X,Y)[source(hyperionleader)] 
  <- .abolish(target(_,_)); 
     +target(X,Y).

+explore[source(hyperionleader)] <- true.