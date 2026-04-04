// nova.asl
// Strategy: each miner gets an exclusive sector from novaleader and sweeps
// it row-by-row. Gold is picked reactively (same priority as dummy).
// No bidding protocol — zero leader-communication overhead mid-game.

/* ── RULES ─────────────────────────────────────────────────────────────── */

go_depot :- carrying_gold(3).
go_depot :- carrying_gold(N) & N > 0 &
            pos(_,_,Step) & steps(_,NSteps) &
            Step + 120 > NSteps.

/* ── REACTIVE PLANS (fire every step, same priority order as dummy) ─────── */

// 1. Standing on gold — pick it, remember the spot
+pos(X,Y,_) : cell(X,Y,gold) & carrying_gold(N) & N < 3
  <- do(pick);
     -+back_pos(X,Y).

// 2. Adjacent gold — step toward it
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

// 5. Arrived at back_pos — advance the sector scan
+pos(X,Y,_) : back_pos(X,Y)
  <- !advance_scan.

// 6. Path to back_pos blocked — advance the sector scan
+pos(X,Y,_) : back_pos(BX,BY) & jia.direction(X,Y,BX,BY,skip)
  <- !advance_scan.

// 7. Moving toward back_pos
+pos(X,Y,_) : back_pos(BX,BY) & jia.direction(X,Y,BX,BY,D)
  <- do(D).

// 8. No back_pos yet — start exploring
+pos(_,_,_)
  <- !advance_scan.

/* ── SECTOR SCAN LOGIC ──────────────────────────────────────────────────── */

// Move right within the current row
+!advance_scan
  : my_sector(X1,Y1,X2,Y2) & scan_target(SX,SY) & SX + 3 =< X2
  <- NSX = SX + 3;
     -+scan_target(NSX,SY);
     -+back_pos(NSX,SY);
     ?pos(X,Y,_);
     jia.direction(X,Y,NSX,SY,D);
     do(D).

// End of row — drop down to the next row, go back to left edge
+!advance_scan
  : my_sector(X1,Y1,X2,Y2) & scan_target(_,SY) & SY + 3 =< Y2
  <- NSY = SY + 3;
     -+scan_target(X1,NSY);
     -+back_pos(X1,NSY);
     ?pos(X,Y,_);
     jia.direction(X,Y,X1,NSY,D);
     do(D).

// Sector fully swept — restart from top-left corner
+!advance_scan : my_sector(X1,Y1,X2,Y2)
  <- -+scan_target(X1,Y1);
     -+back_pos(X1,Y1);
     ?pos(X,Y,_);
     jia.direction(X,Y,X1,Y1,D);
     do(D).

// No sector yet — fall back to least-visited tile
+!advance_scan : pos(X,Y,_) & jia.near_least_visited(X,Y,TX,TY)
  <- -+back_pos(TX,TY);
     jia.direction(X,Y,TX,TY,D);
     do(D).

// Ultimate fallback — wider random move
+!advance_scan
  <- ?pos(X,Y,_);
     jia.random(RX,40); NX = (RX-20)+X;
     jia.random(RY,40); NY = (RY-20)+Y;
     -+back_pos(NX,NY);
     jia.direction(X,Y,NX,NY,D);
     do(D).

-!advance_scan <- do(skip).

/* ── RECEIVE SECTOR FROM LEADER ─────────────────────────────────────────── */

+my_sector(X1,Y1,X2,Y2)
  <- -+scan_target(X1,Y1);
     -+back_pos(X1,Y1).
