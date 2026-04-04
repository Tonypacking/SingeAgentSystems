// toiletleader.asl

// When a miner tells us about gold, remember it.
+found_gold(X, Y)[source(Ag)] 
  <- +known_gold(X, Y).

// When asked for a target, give the first known gold coordinate and remove it from memory.
+!get_target[source(Ag)] : known_gold(X, Y) 
  <- -known_gold(X, Y); 
     .send(Ag, tell, target(X, Y)).

// If asked but we have no known gold, tell them to keep exploring.
+!get_target[source(Ag)] : not known_gold(_, _) 
  <- .send(Ag, tell, explore).