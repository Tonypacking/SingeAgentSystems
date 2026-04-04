// sigma.asl

/* =========================================================
   RULES & MATH
========================================================= */
go_depot :- carrying_gold(3).

// THE TIME HACK: Tighter buffer (15 instead of 40) for absolute maximum mining time.
go_depot :- carrying_gold(N) & N > 0 & 
            pos(X,Y,Step) & steps(_,NSteps) & 
            depot(_,DX,DY) & 
            (Step + math.abs(X - DX) + math.abs(Y - DY) + 15) > NSteps.

/* =========================================================
   CORE MOVEMENT LOGIC
========================================================= */

// 1. On gold -> Pick it up, clear exploration target, REMEMBER IT!
+pos(X,Y,_) : cell(X,Y,gold) & carrying_gold(N) & N < 3
  <- do(pick);
     .abolish(target(_,_));
     -+last_gold(X,Y).

// 2. Adjacent gold -> Step to it
+pos(X,Y,_) : cell(GX,GY,gold) & carrying_gold(N) & N < 3
  <- jia.direction(X, Y, GX, GY, D);
     do(D).

// 3. See extra gold but full? -> SHOUT IT TO THE TEAM!
+cell(GX,GY,gold) : carrying_gold(3) & not reported(GX,GY)
  <- .broadcast(tell, shared_gold(GX,GY));
     +reported(GX,GY).

// 4. At depot -> Drop
+pos(X,Y,_) : go_depot & depot(_,X,Y)
  <- do(drop).

// 5. Move to depot
+pos(X,Y,_) : go_depot & depot(_,DX,DY)
  <- jia.direction(X, Y, DX, DY, D);
     do(D).

// 6. Return to personal gold (Stubborn Memory)
+pos(X,Y,_) : not go_depot & last_gold(LX,LY)
  <- jia.direction(X, Y, LX, LY, D);
     !execute_return(D).

// 7. Swarm to team's shared gold
+pos(X,Y,_) : not go_depot & not last_gold(_,_) & shared_gold(SX,SY)
  <- jia.direction(X, Y, SX, SY, D);
     !execute_shared(D).

// 8. Follow exploration target
+pos(X,Y,_) : not go_depot & not last_gold(_,_) & not shared_gold(_,_) & target(TX,TY)
  <- jia.direction(X, Y, TX, TY, D);
     !execute_target(D).

// 9. Default explore
+pos(_,_,_)
  <- !define_new_pos.

/* =========================================================
   EXECUTION HELPERS (Crash-Proof)
========================================================= */

+!execute_return(skip) <- .abolish(last_gold(_,_)); !define_new_pos.
+!execute_return(D) <- do(D).

+!execute_shared(skip) <- .abolish(shared_gold(_,_)); !define_new_pos.
+!execute_shared(D) <- do(D).

+!execute_target(skip) <- .abolish(target(_,_)); !define_new_pos.
+!execute_target(D) <- do(D).

/* -- SAFE EXPLORATION -- */
// By calculating the math inside the plan body instead of a strict rule, 
// the agent will NEVER crash even if the math yields a negative coordinate.
+!define_new_pos : pos(X,Y,_)
  <- jia.random(RX,40); NX = (RX-20)+X;
     jia.random(RY,40,5); NY = (RY-20)+Y;
     -+target(NX,NY);
     jia.direction(X, Y, NX, NY, D);
     do(D).

// Ultimate fallback: If math breaks, just skip turn, don't drop intention.
-!define_new_pos <- do(skip).

// Receive team broadcasts
+shared_gold(X,Y)[source(Ag)] <- +shared_gold(X,Y).