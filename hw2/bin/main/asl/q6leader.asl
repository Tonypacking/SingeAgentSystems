// Q6 Leader Agent
//
// Strategy: 6-Quadrant
//   - Divides the map into a 3-column x 2-row grid (6 quadrants).
//   - Assigns one quadrant to each of q6m1..q6m6 at game start.
//   - Runs the gold-allocation bidding protocol (waits for 5 bids).
//   - Maintains a central gold-knowledge map and re-broadcasts new gold.
//   - Reacts to "lot_of_gold_in_quadrant" from miners -> tracks rich quadrants.
//   - Reacts to "quadrant_explored" reports -> if a miner's quadrant had too
//     little gold AND there is a rich quadrant elsewhere, redirect the miner.

/* -- Thresholds -- */

lot_of_gold_threshold(3).
low_gold_threshold(2).


/* -- 1. Quadrant assignment at game start (3 columns x 2 rows) -- */

@q6quads[atomic]
+gsize(S,W,H)
  <- .print("Q6Leader: 3x2 quadrants for sim ", S, " (", W, "x", H, ")");
     ColW = W div 3;
     RowH = H div 2;
     // Row 0 (top)
     +quad(S,1,  0,         0,       ColW - 1,       RowH - 1);
     +quad(S,2,  ColW,      0,       2 * ColW - 1,   RowH - 1);
     +quad(S,3,  2 * ColW,  0,       W - 1,          RowH - 1);
     // Row 1 (bottom)
     +quad(S,4,  0,         RowH,    ColW - 1,       H - 1);
     +quad(S,5,  ColW,      RowH,    2 * ColW - 1,   H - 1);
     +quad(S,6,  2 * ColW,  RowH,    W - 1,          H - 1);
     !q6_inform_quad(S, q6m1, 1);
     !q6_inform_quad(S, q6m2, 2);
     !q6_inform_quad(S, q6m3, 3);
     !q6_inform_quad(S, q6m4, 4);
     !q6_inform_quad(S, q6m5, 5);
     !q6_inform_quad(S, q6m6, 6).

// Send quadrant to miner — skip if depot falls inside this quadrant.
+!q6_inform_quad(S, Miner, Q)
  : quad(S,Q,X1,Y1,X2,Y2) &
    depot(S,DX,DY) &
    not (DX >= X1 & DX =< X2 & DY >= Y1 & DY =< Y2)
  <- .print("Q6Leader: quadrant ", Q, " (", X1,",",Y1,")-(", X2,",",Y2, ") -> ", Miner);
     .send(Miner, tell, quadrant(X1,Y1,X2,Y2)).
// Depot is inside this quadrant: send the full map so miner still has work.
+!q6_inform_quad(S, Miner, _)
  : gsize(S,W,H)
  <- .print("Q6Leader: ", Miner, " got depot quadrant -- assigning full map.");
     .send(Miner, tell, quadrant(0, 0, W-1, H-1)).
+!q6_inform_quad(_, _, _).


/* -- 2. Gold-allocation bidding protocol (5 bids = all non-finder miners) -- */

+bid(Gold,D,Ag)
  : .count(bid(Gold,_,_),5)
  <- !q6_allocate_miner(Gold);
     .abolish(bid(Gold,_,_)).

+!q6_allocate_miner(Gold)
  <- .findall(op(Dist,A), bid(Gold,Dist,A), LD);
     .min(LD, op(DistCloser,Closer));
     DistCloser < 10000;
     .print("Q6Leader: allocated ", Gold, " -> ", Closer, " bids=", LD);
     .broadcast(tell, allocated(Gold,Closer)).
-!q6_allocate_miner(Gold)
  <- .print("Q6Leader: could not allocate ", Gold).


/* -- 3. Central gold-knowledge map + re-broadcasting -- */

+gold(X,Y)[source(Ag)] : Ag \== self
  <- if (not known_gold(X,Y)) {
         +known_gold(X,Y);
         .print("Q6Leader: new gold (", X, ",", Y, ") from ", Ag);
         .broadcast(tell, gold(X,Y))
     };
     .broadcast(untell, allocated(gold(X,Y),Ag));
     .abolish(gold(_,_)).

+picked(gold(X,Y))[source(Ag)] : Ag \== self
  <- .print("Q6Leader: gold (", X, ",", Y, ") picked.");
     -known_gold(X,Y);
     .broadcast(tell, picked(gold(X,Y))).


/* -- 4. Track rich quadrants -- */

@q6lot_gold[atomic]
+lot_of_gold_in_quadrant(Miner, X1, Y1, X2, Y2)[source(Miner)]
  : not rich_quadrant(Miner, X1, Y1, X2, Y2)
  <- .print("Q6Leader: LOT OF GOLD from ", Miner, " in (", X1,",",Y1,")-(", X2,",",Y2,")");
     +rich_quadrant(Miner, X1, Y1, X2, Y2).


/* -- 5. Exploration reports -> redirect miners with poor quadrants -- */

@q6quad_explored[atomic]
+quadrant_explored(Miner, X1, Y1, X2, Y2, Count)[source(Miner)]
  <- .print("Q6Leader: ", Miner, " explored (", X1,",",Y1,")-(", X2,",",Y2,") found=", Count);
     +quadrant_report(Miner, X1, Y1, X2, Y2, Count);
     low_gold_threshold(LowThresh);
     if (Count < LowThresh) {
         .print("Q6Leader: ", Miner, " has poor quadrant -- looking for richer area.");
         !q6_maybe_redirect(Miner)
     }.

+!q6_maybe_redirect(Miner)
  // Find the richest quadrant (by currently known gold count) that belongs to
  // a different miner and still has enough gold to be worth redirecting to.
  : .findall(r(C, RX1, RY1, RX2, RY2),
             (rich_quadrant(OtherMiner, RX1, RY1, RX2, RY2) &
              .findall(g,
                       (known_gold(GX,GY) &
                        GX >= RX1 & GX =< RX2 &
                        GY >= RY1 & GY =< RY2),
                       GL) &
              .length(GL, C) &
              OtherMiner \== Miner),
             Candidates) &
    .length(Candidates, NC) & NC > 0 &
    .max(Candidates, r(BestCount, BX1, BY1, BX2, BY2)) &
    lot_of_gold_threshold(LotThresh) &
    BestCount >= LotThresh
  <- .print("Q6Leader: redirecting ", Miner, " to (", BX1,",",BY1,")-(", BX2,",",BY2,") gold=", BestCount);
     .send(Miner, tell, mine_in_quadrant(BX1, BY1, BX2, BY2)).
+!q6_maybe_redirect(Miner)
  <- .print("Q6Leader: no rich quadrant available for ", Miner).


/* -- End of simulation -- */

+end_of_simulation(S,R)
  <- .print("Q6Leader -- END ", S, ": ", R);
     .abolish(quad(S,_,_,_,_,_));
     .abolish(known_gold(_,_));
     .abolish(rich_quadrant(_,_,_,_,_));
     .abolish(quadrant_report(_,_,_,_,_,_)).
