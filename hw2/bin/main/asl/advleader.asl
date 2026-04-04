// Advanced Leader Agent (ported from leader2.asl in gold-miners-II)
//
// Responsibilities:
//   1. Assign one quadrant to each of the four quadrant miners (adv1-4) at start.
//   2. Run the gold-allocation bidding protocol.
//   3. Maintain a central gold-knowledge map and broadcast every update.
//   4. React to "lot_of_gold_in_quadrant" from a quadrant miner:
//        -> dispatch adv5 (right half) or adv6 (left half) scout there.
//   5. React to "quadrant_explored" end-of-exploration reports:
//        -> if a miner found too little gold AND another quadrant has lots -> redirect.
//
// Note: "picked" is NOT discarded so the leader can react to it.

/* -- Thresholds -- */

lot_of_gold_threshold(3).
low_gold_threshold(2).


/* -- 1. Quadrant assignment at game start -- */

@advquads[atomic]
+gsize(S,W,H)
  <- .print("AdvLeader: defining quadrants for sim ", S, " (", W, "x", H, ")");
     CellH = H div 2;
     +quad(S,1,  0,       0,       W div 2 - 1, CellH - 1);
     +quad(S,2,  W div 2, 0,       W - 1,       CellH - 1);
     +quad(S,3,  0,       CellH,   W div 2 - 1, (CellH*2)-1);
     +quad(S,4,  W div 2, CellH,   W - 1,       (CellH*2)-1);

     !adv_inform_quad(S, adv1, 1);
     !adv_inform_quad(S, adv2, 2);
     !adv_inform_quad(S, adv3, 3);
     !adv_inform_quad(S, adv4, 4).

+!adv_inform_quad(S, Miner, Q)
  : quad(S,Q,X1,Y1,X2,Y2) &
    depot(S,DX,DY) &
    not (DX >= X1 & DX =< X2 & DY >= Y1 & DY =< Y2)
  <- .print("AdvLeader: sending quadrant ", Q, " (", X1,",",Y1,")-(", X2,",",Y2, ") to ", Miner);
     .send(Miner, tell, quadrant(X1,Y1,X2,Y2)).
+!adv_inform_quad(_, Miner, _)
  <- .print("AdvLeader: ", Miner, " is in the depot quadrant -- skipping.").


/* -- 2. Gold-allocation bidding protocol -- */

+bid(Gold,D,Ag)
  : .count(bid(Gold,_,_),5)
  <- !adv_allocate_miner(Gold);
     .abolish(bid(Gold,_,_)).

+!adv_allocate_miner(Gold)
  <- .findall(op(Dist,A), bid(Gold,Dist,A), LD);
     .min(LD, op(DistCloser,Closer));
     DistCloser < 10000;
     .print("AdvLeader: allocated ", Gold, " -> ", Closer, " (options: ", LD, ")");
     .broadcast(tell, allocated(Gold,Closer)).
-!adv_allocate_miner(Gold)
  <- .print("AdvLeader: could not allocate ", Gold).


/* -- 3. Central gold-knowledge map + broadcasting -- */

+gold(X,Y)[source(Ag)] : Ag \== self
  <- if (not known_gold(X,Y)) {
         +known_gold(X,Y);
         .print("AdvLeader: new gold (", X, ",", Y, ") from ", Ag, " -- broadcasting.");
         .broadcast(tell, gold(X,Y))
     };
     .broadcast(untell, allocated(gold(X,Y),Ag));
     .abolish(gold(_,_)).

+picked(gold(X,Y))[source(Ag)] : Ag \== self
  <- .print("AdvLeader: gold (", X, ",", Y, ") removed -- broadcasting.");
     -known_gold(X,Y);
     .broadcast(tell, picked(gold(X,Y))).


/* -- 4. Lot-of-gold alert -> dispatch a scout -- */

@advlot_gold[atomic]
+lot_of_gold_in_quadrant(Miner, X1, Y1, X2, Y2)[source(Miner)]
  : not scout_dispatched_to(X1,Y1,X2,Y2)
  <- .print("AdvLeader: LOT OF GOLD reported by ", Miner, " in (", X1,",",Y1,")-(", X2,",",Y2,")");
     +rich_quadrant(Miner, X1, Y1, X2, Y2);
     +scout_dispatched_to(X1,Y1,X2,Y2);
     !adv_dispatch_scout_to(X1, Y1, X2, Y2).

+!adv_dispatch_scout_to(X1, Y1, X2, Y2)
  : gsize(_,W,_)
  <- MidX = W / 2;
     if (X1 >= MidX) { Scout = adv5 } else { Scout = adv6 };
     .print("AdvLeader: sending ", Scout, " to mine (", X1,",",Y1,")-(", X2,",",Y2,")");
     .send(Scout, tell, mine_in_quadrant(X1, Y1, X2, Y2)).
+!adv_dispatch_scout_to(_,_,_,_).


/* -- 5. End-of-exploration reports -> redirect poor miners -- */

@advquad_explored[atomic]
+quadrant_explored(Miner, X1, Y1, X2, Y2, Count)[source(Miner)]
  <- .print("AdvLeader: ", Miner, " explored (", X1,",",Y1,")-(", X2,",",Y2,") -- ", Count, " golds.");
     +quadrant_gold_report(Miner, X1, Y1, X2, Y2, Count);
     low_gold_threshold(LowThresh);
     if (Count < LowThresh) {
         .print("AdvLeader: ", Miner, " found little gold -- checking for richer quadrant.");
         !adv_maybe_redirect(Miner)
     }.

+!adv_maybe_redirect(Miner)
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
  <- .print("AdvLeader: redirecting ", Miner, " to rich quadrant (", BX1,",",BY1,")-(", BX2,",",BY2,") with ", BestCount, " golds.");
     .send(Miner, tell, mine_in_quadrant(BX1, BY1, BX2, BY2)).
+!adv_maybe_redirect(Miner)
  <- .print("AdvLeader: no rich quadrant available to redirect ", Miner).


/* -- End of simulation -- */

+end_of_simulation(S,R)
  <- .print("AdvLeader -- END ", S, ": ", R);
     .abolish(quad(S,_,_,_,_,_));
     .abolish(known_gold(_,_));
     .abolish(rich_quadrant(_,_,_,_,_));
     .abolish(scout_dispatched_to(_,_,_,_));
     .abolish(quadrant_gold_report(_,_,_,_,_,_)).
