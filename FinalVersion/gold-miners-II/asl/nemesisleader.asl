// nemesisleader.asl

// 1. Miner reports a vein -> Save it
+found_vein(X,Y)[source(Ag)] : not known_vein(X,Y)
  <- +known_vein(X,Y).

// 2. Empty miner asks for work -> Give them one vein, DELETE IT so no one else goes there
+!get_target[source(Ag)] : known_vein(X,Y)
  <- -known_vein(X,Y);
     .send(Ag, tell, target(X,Y)).

// 3. Miner asks, but we have no gold -> Tell them to explore
+!get_target[source(Ag)]
  <- .send(Ag, tell, explore).