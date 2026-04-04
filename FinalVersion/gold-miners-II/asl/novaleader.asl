// novaleader.asl
// Minimal leader: divides the map into 6 vertical strips at game start
// and tells each miner its assigned sector. No gold-bidding overhead.

@nova_start[atomic]
+gsize(S,W,H)
  <- ColW = W div 6;
     .send(nova1, tell, my_sector(0,           0, ColW-1,     H-1));
     .send(nova2, tell, my_sector(ColW,        0, 2*ColW-1,   H-1));
     .send(nova3, tell, my_sector(2*ColW,      0, 3*ColW-1,   H-1));
     .send(nova4, tell, my_sector(3*ColW,      0, 4*ColW-1,   H-1));
     .send(nova5, tell, my_sector(4*ColW,      0, 5*ColW-1,   H-1));
     .send(nova6, tell, my_sector(5*ColW,      0, W-1,        H-1)).

+end_of_simulation(S,R)
  <- .print("novaleader -- END ", S, ": ", R).
