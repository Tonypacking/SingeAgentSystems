// toiletleader.asl

// 1. When a miner reports gold, add it to memory ONLY if we don't already know about it.
+found_gold(X, Y) : not known_gold(X, Y)
  <- +known_gold(X, Y).

// 2. When a miner asks for a target, give them one and remove it from memory.
+!get_target[source(Ag)] : known_gold(X, Y) 
  <- -known_gold(X, Y); 
     .send(Ag, tell, target(X, Y)).

// 3. If a miner asks but memory is empty, tell them to explore.
+!get_target[source(Ag)]
  <- .send(Ag, tell, explore).