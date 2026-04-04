// Leader Agent (version 2)
//
// Responsibilities:
//   1. Assign one quadrant to each of the four quadrant miners at game start.
//   2. Run the gold-allocation bidding protocol (unchanged from original).
//   3. Maintain a central gold-knowledge map and broadcast every update
//      so all agents always have an up-to-date picture of gold/empty cells.
//   4. React to "lot_of_gold_in_quadrant" from a quadrant miner:
//        → dispatch the appropriate scout (scout1=right, scout2=left) there.
//   5. React to "quadrant_explored" end-of-exploration reports:
//        → if a miner found too little gold (< low_gold_threshold) AND
//          another quadrant has lots of gold → redirect that miner.
//
// Belief-base note:
//   Uses DiscardBelsBB("my_status","committed_to","cell") — i.e. "picked"
//   is intentionally NOT discarded here so the leader can react to it.

/* ── Thresholds ────────────────────────────────────────────────────────── */

lot_of_gold_threshold(3).   // same value as in quadrant_miner.asl
low_gold_threshold(2).       // miner found < 2 golds → candidate for redirect


/* ── 1. Quadrant assignment at game start ───────────────────────────────── */

@quads[atomic]
+gsize(S,W,H)
  <- .print("Leader: defining quadrants for sim ", S, " (", W, "x", H, ")");
     CellH = H div 2;
     +quad(S,1,  0,       0,       W div 2 - 1, CellH - 1);
     +quad(S,2,  W div 2, 0,       W - 1,       CellH - 1);
     +quad(S,3,  0,       CellH,   W div 2 - 1, (CellH*2)-1);
     +quad(S,4,  W div 2, CellH,   W - 1,       (CellH*2)-1);

     !inform_quad(S, miner1, 1);
     !inform_quad(S, miner2, 2);
     !inform_quad(S, miner3, 3);
     !inform_quad(S, miner4, 4).

// Send quadrant to a miner only if the depot is not inside it
+!inform_quad(S, Miner, Q)
  : quad(S,Q,X1,Y1,X2,Y2) &
    depot(S,DX,DY) &
    not (DX >= X1 & DX =< X2 & DY >= Y1 & DY =< Y2)
  <- .print("Leader: sending quadrant ", Q, " (", X1,",",Y1,")-(", X2,",",Y2, ") to ", Miner);
     .send(Miner, tell, quadrant(X1,Y1,X2,Y2)).
+!inform_quad(_, Miner, _)
  <- .print("Leader: ", Miner, " is in the depot quadrant — skipping.").


/* ── 2. Gold-allocation bidding protocol (original logic) ───────────────── */

+bid(Gold,D,Ag)
  : .count(bid(Gold,_,_),5)   // wait for all five non-finder bids
  <- !allocate_miner(Gold);
     .abolish(bid(Gold,_,_)).

+!allocate_miner(Gold)
  <- .findall(op(Dist,A), bid(Gold,Dist,A), LD);
     .min(LD, op(DistCloser,Closer));
     DistCloser < 10000;
     .print("Leader: allocated ", Gold, " → ", Closer, " (options: ", LD, ")");
     .broadcast(tell, allocated(Gold,Closer)).
-!allocate_miner(Gold)
  <- .print("Leader: could not allocate ", Gold).


/* ── 3. Central gold-knowledge map + broadcasting ───────────────────────── */

// New gold reported by any agent
// — add to knowledge map, broadcast to all, then run re-announcement logic
+gold(X,Y)[source(Ag)] : Ag \== self
  <- if (not known_gold(X,Y)) {
         +known_gold(X,Y);
         .print("Leader: new gold (", X, ",", Y, ") from ", Ag, " — broadcasting.");
         .broadcast(tell, gold(X,Y))    // triggers bidding in all agents
     };
     // original re-announcement: cancel stale allocations
     .broadcast(untell, allocated(gold(X,Y),Ag));
     .abolish(gold(_,_)).

// Gold was picked up / cell confirmed empty
+picked(gold(X,Y))[source(Ag)] : Ag \== self
  <- .print("Leader: gold (", X, ",", Y, ") removed — broadcasting.");
     -known_gold(X,Y);
     .broadcast(tell, picked(gold(X,Y))).


/* ── 4. Lot-of-gold alert → dispatch a scout ───────────────────────────── */

@lot_gold[atomic]
+lot_of_gold_in_quadrant(Miner, X1, Y1, X2, Y2)[source(Miner)]
  : not scout_dispatched_to(X1,Y1,X2,Y2)
  <- .print("Leader: LOT OF GOLD reported by ", Miner, " in (", X1,",",Y1,")-(", X2,",",Y2,")");
     +rich_quadrant(Miner, X1, Y1, X2, Y2);
     +scout_dispatched_to(X1,Y1,X2,Y2);
     !dispatch_scout_to(X1, Y1, X2, Y2).

+!dispatch_scout_to(X1, Y1, X2, Y2)
  : gsize(_,W,_)
  <- MidX = W / 2;
     // Scout1 covers the right half, scout2 the left half
     if (X1 >= MidX) { Scout = scout1 } else { Scout = scout2 };
     .print("Leader: sending ", Scout, " to mine (", X1,",",Y1,")-(", X2,",",Y2,")");
     .send(Scout, tell, mine_in_quadrant(X1, Y1, X2, Y2)).
+!dispatch_scout_to(_,_,_,_).  // gsize not yet known — skip for now


/* ── 5. End-of-exploration reports → redirect poor miners ──────────────── */

@quad_explored[atomic]
+quadrant_explored(Miner, X1, Y1, X2, Y2, Count)[source(Miner)]
  <- .print("Leader: ", Miner, " explored (", X1,",",Y1,")-(", X2,",",Y2,") — ", Count, " golds.");
     +quadrant_gold_report(Miner, X1, Y1, X2, Y2, Count);
     low_gold_threshold(LowThresh);
     if (Count < LowThresh) {
         .print("Leader: ", Miner, " found little gold — checking for richer quadrant.");
         !maybe_redirect(Miner)
     }.

// Find the richest OTHER quadrant and redirect the poor miner there
+!maybe_redirect(Miner)
  : .findall(r(C,RX1,RY1,RX2,RY2),
             (rich_quadrant(OtherMiner, RX1,RY1,RX2,RY2) &
              .findall(g, known_gold(GX,GY) & GX >= RX1 & GX =< RX2 &
                           GY >= RY1 & GY =< RY2, GL) &
              .length(GL, C) &
              OtherMiner \== Miner),
             Candidates) &
    .length(Candidates, NC) & NC > 0 &
    .max(Candidates, r(BestCount,BX1,BY1,BX2,BY2)) &
    lot_of_gold_threshold(LotThresh) &
    BestCount >= LotThresh
  <- .print("Leader: redirecting ", Miner, " to rich quadrant (", BX1,",",BY1,")-(", BX2,",",BY2,") with ", BestCount, " golds.");
     .send(Miner, tell, mine_in_quadrant(BX1, BY1, BX2, BY2)).
+!maybe_redirect(Miner)
  <- .print("Leader: no rich quadrant available to redirect ", Miner).


/* ── End of simulation ──────────────────────────────────────────────────── */

+end_of_simulation(S,R)
  <- .print("Leader -- END ", S, ": ", R);
     .abolish(quad(S,_,_,_,_,_));
     .abolish(known_gold(_,_));
     .abolish(rich_quadrant(_,_,_,_,_));
     .abolish(scout_dispatched_to(_,_,_,_));
     .abolish(quadrant_gold_report(_,_,_,_,_,_)).
