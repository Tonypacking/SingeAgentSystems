// sabotage.asl — 4-side depot blocking
//
// miner1 = east  (DX+1, DY)
// miner2 = west  (DX-1, DY)
// miner3 = south (DX,   DY+1)
// miner4 = north (DX,   DY-1) — yields left when an allied miner passes through
//
// All plans are guarded so they only fire for miner1-4.
// miner5-6 fall through to the normal mining plans.

/* ------------------------------------------------------------------ */
/* Blocker offset table (relative to depot)                           */
/* ------------------------------------------------------------------ */

blocker_offset(skibidy_miner1,  1,  0).
blocker_offset(skibidy_miner2, -1,  0).
blocker_offset(skibidy_miner3,  0,  1).
blocker_offset(skibidy_miner4,  0, -1).

/* ------------------------------------------------------------------ */
/* Start-up: blockers skip normal mining and go to their post         */
/* ------------------------------------------------------------------ */

@blocker_start[atomic]
+pos(_,_,0) : .my_name(Me) & blocker_offset(Me, OX, OY)
  <- ?depot(_,DX,DY);
     TX = DX + OX;
     TY = DY + OY;
     .print(Me, " is depot blocker at ", TX, ",", TY);
     -+block_pos(TX, TY);
     !!block_depot.

/* ------------------------------------------------------------------ */
/* Blockers ignore gold broadcasts — never bid, never fetch           */
/* ------------------------------------------------------------------ */

+gold(_,_)[source(A)] : .my_name(Me) & blocker_offset(Me,_,_) & A \== self.

/* ------------------------------------------------------------------ */
/* End-of-simulation and restart                                       */
/* ------------------------------------------------------------------ */

+end_of_simulation(S,R) : .my_name(Me) & blocker_offset(Me,_,_)
  <- .drop_all_desires;
     .print("-- BLOCKER END ",S,": ",R).

@blocker_restart[atomic]
+restart : .my_name(Me) & blocker_offset(Me,_,_)
  <- .drop_all_desires;
     !!block_depot.

/* ------------------------------------------------------------------ */
/* Main blocking loop                                                   */
/* ------------------------------------------------------------------ */

+!block_depot
  <- ?block_pos(TX,TY);
     .print("Blocker heading to post at ", TX, ",", TY);
     !pos(TX,TY);
     !!harass_depot.

-!block_depot
  <- .print("Blocker: failed to reach post, retrying.");
     !!block_depot.

// Each cycle: return to post if displaced, then push/yield
+!harass_depot
  <- ?block_pos(TX,TY);
     !return_to_post(TX,TY);
     !push_or_yield;
     !!harass_depot.

-!harass_depot
  <- !!harass_depot.

+!return_to_post(TX,TY) : pos(TX,TY,_).
+!return_to_post(TX,TY) <- !pos(TX,TY).

/* ------------------------------------------------------------------ */
/* Push enemies; miner4 (north) also yields for allied miners         */
/* ------------------------------------------------------------------ */

// Enemy pushing — all blockers, highest priority
+!push_or_yield : pos(X,Y,_) & cell(X+1,Y,enemy) <- do(right).
+!push_or_yield : pos(X,Y,_) & cell(X-1,Y,enemy) <- do(left).
+!push_or_yield : pos(X,Y,_) & cell(X,Y-1,enemy) <- do(up).
+!push_or_yield : pos(X,Y,_) & cell(X,Y+1,enemy) <- do(down).

// miner4: yield left when allied miner is approaching from north (cell to north)
+!push_or_yield : .my_name(skibidy_miner4) & pos(X,Y,_) & cell(X,Y-1,ally) <- do(left).
// miner4: yield left when allied miner is at depot (cell to south) trying to leave
+!push_or_yield : .my_name(skibidy_miner4) & pos(X,Y,_) & cell(X,Y+1,ally) <- do(left).

+!push_or_yield.  // stand ground — no enemy or ally to handle
