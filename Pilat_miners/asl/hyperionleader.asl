// hyperionleader.asl

// 1. Miner reports gold -> Add to memory
+found_gold(X,Y)[source(Ag)] : not known_gold(X,Y)
  <- +known_gold(X,Y).

// 2. Miner asks for work AND we have gold -> Give it to them, then DELETE IT!
+!get_target[source(Ag)] : known_gold(X,Y)
  <- -known_gold(X,Y); // Deleting ensures no two miners get the same coordinate
     .send(Ag, tell, target(X,Y)).

// 3. Miner asks for work but we have no gold -> Tell them to explore
+!get_target[source(Ag)]
  <- .send(Ag, tell, explore).