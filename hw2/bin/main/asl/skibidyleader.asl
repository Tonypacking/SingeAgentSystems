// skibidyleader.asl

// When a miner tells the leader about gold, save it as a belief
+found_gold(X, Y)[source(Miner)] 
  <- +known_gold(X, Y).

// When a miner asks for a target, and we KNOW where gold is
+!get_target[source(Miner)] : known_gold(X, Y) 
  <- -known_gold(X, Y); // Remove it from the list so we don't send everyone to the same spot
     .send(Miner, tell, target(X, Y)). // Dispatch the miner

// When a miner asks for a target, but we DON'T know where any gold is
+!get_target[source(Miner)] : not known_gold(_, _) 
  <- .send(Miner, tell, explore). // Tell them to keep searching