// mars robot 4 - collector (same role as r1, covers different area)

/* Initial beliefs */

at(P) :- pos(P,X,Y) & pos(r4,X,Y).

/* Initial goal */

!check(slots).

/* Plans */

+!check(slots) : not garbage(r4)
   <- next(slot);
      !check(slots).


+garbage(r4) : not .desire(carry_to(_))
   <- ?pos(r4,X1,Y1);
      ?pos(r2,X2,Y2);
      ?pos(r3,X3,Y3);
      D2 = (X1-X2)*(X1-X2) + (Y1-Y2)*(Y1-Y2);
      D3 = (X1-X3)*(X1-X3) + (Y1-Y3)*(Y1-Y3);
      if (D2 <= D3) { !carry_to(r2) } else { !carry_to(r3) }.

+!carry_to(R)
   <- .drop_desire(check(slots));

      // remember where to go back
      ?pos(r4,X,Y);
      -+pos(last,X,Y);

      // carry garbage to burner
      !take(garb,R);

      // goes back and continue to check
      !at(last);
      !!check(slots).


+!take(S,L)
   <- !ensure_pick(S);
      !at(L);
      drop(S).

+!ensure_pick(S) : garbage(r4)
   <- pick(garb);
      !ensure_pick(S).
+!ensure_pick(_).

+!at(L) : at(L).
+!at(L) <- ?pos(L,X,Y);
           move_towards(X,Y);
           !at(L).
