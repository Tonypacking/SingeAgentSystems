// stupidleader.asl

+found_gold(X, Y) : not known_gold(X, Y)
  <- +known_gold(X, Y).

+!get_target[source(Ag)] : known_gold(X, Y) 
  <- -known_gold(X, Y); 
     .send(Ag, tell, target(X, Y)).

+!get_target[source(Ag)]
  <- .send(Ag, tell, explore).