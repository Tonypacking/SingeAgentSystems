// apex_leader.asl

// 1. A miner reports a gold location
+found_gold(X,Y)[source(Ag)] : not known_gold(X,Y)
  <- +known_gold(X,Y).

// 2. A miner asks for a target
+!get_job[source(Ag)] : known_gold(X,Y)
  <- -known_gold(X,Y); // Remove it so no one else gets it
     .send(Ag, tell, target(X,Y)).

// 3. No gold known? Tell them to keep exploring
+!get_job[source(Ag)]
  <- .send(Ag, tell, explore).