go_depot :- carrying_gold(3).
go_depot :- carrying_gold(N) & N > 0 & pos(_,_,Step) & steps(_,NSteps) & (Step + 120) > NSteps.

random_pos(X,Y) :-
   pos(AgX,AgY,_) &
   jia.random(RX,30) & X = (RX-15)+AgX & X > 0 & 
   jia.random(RY,30,5) & Y = (RY-15)+AgY &
   not jia.obstacle(X,Y).


+pos(X,Y,_) : cell(GX,GY,gold) & not reported(GX,GY)
   <- .send(leader, tell, found_vein(GX,GY));
      +reported(GX,GY).

+pos(X,Y,_) : cell(X,Y,gold) & carrying_gold(N) & N < 3
   <- do(pick);
      .abolish(target(_,_)); 
      -+back_pos(X,Y).

+pos(X,Y,_) : cell(GX,GY,gold) & carrying_gold(N) & N < 3
   <- jia.direction(X, Y, GX, GY, D);
      do(D).

+pos(X,Y,_) : go_depot & depot(_,X,Y)
   <- do(drop);
      .abolish(target(_,_));
      .send(leader, achieve, get_target). 

+pos(X,Y,_) : go_depot & depot(_,DX,DY)
   <- jia.direction(X, Y, DX, DY, D);
      do(D).

+pos(X,Y,_) : back_pos(BX,BY)
   <- jia.direction(X,Y,BX,BY,D);
      if (D == skip) {
         .abolish(back_pos(_,_));
         .send(leader, achieve, get_target);
         !define_new_pos;
      } else {
         do(D);
      }.

+pos(X,Y,_) : target(TX,TY)
   <- jia.direction(X,Y,TX,TY,D);
      if (D == skip) {
         .abolish(target(TX,TY));
         .send(leader, achieve, get_target);
         !define_new_pos;
      } else {
         do(D);
      }.

+pos(_,_,_) <- !define_new_pos.

+!define_new_pos : not target(_,_)
   <- ?pos(X,Y,_);
      ?random_pos(NX,NY);
      +target(NX,NY); 
      jia.direction(X, Y, NX, NY, D);
      do(D).
+!define_new_pos.

+target(X,Y)[source(leader)] <- .abolish(target(_,_)); +target(X,Y).
+explore[source(leader)] <- .abolish(target(_,_)).