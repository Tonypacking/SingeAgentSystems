+found_vein(X,Y)[source(Ag)] : not known_vein(X,Y)
   <- +known_vein(X,Y);
      !dispatch_to_waiting.

+!dispatch_to_waiting : known_vein(X,Y) & waiting(Ag)
   <- -known_vein(X,Y);
      -waiting(Ag);
      .send(Ag, tell, target(X,Y)).
+!dispatch_to_waiting.

+!get_target[source(Ag)] : known_vein(X,Y)
   <- -known_vein(X,Y);
      .send(Ag, tell, target(X,Y)).

+!get_target[source(Ag)]
   <- +waiting(Ag);
      .send(Ag, tell, explore).