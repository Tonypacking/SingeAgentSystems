// scout_leader agent
// Divides the map into 4 quadrants and assigns one to each of scout_miner1-4.
// scout_miner5 and scout_miner6 start free and join when a rich quadrant is announced.

@quads[atomic]
+gsize(S,W,H)
  <- .print("Defining quadrants for simulation ",S,": ",W,"x",H);
     CellH = H div 2;
     CellW = W div 2;
     +quad(S,1, 0,     0,      W div 2 - 1, CellH - 1);
     +quad(S,2, CellW, 0,      W - 1,       CellH - 1);
     +quad(S,3, 0,     CellH,  W div 2 - 1, H - 1);
     +quad(S,4, CellW, CellH,  W - 1,       H - 1);
     !inform_quad(S, scout_miner1, 1);
     !inform_quad(S, scout_miner2, 2);
     !inform_quad(S, scout_miner3, 3);
     !inform_quad(S, scout_miner4, 4).

// Send the quadrant only if the depot is not inside it
+!inform_quad(S, Miner, Q)
  :  quad(S,Q,X1,Y1,X2,Y2) &
     depot(S,DX,DY) &
     not (DX >= X1 & DX =< X2 & DY >= Y1 & DY =< Y2)
  <- .print("Assigning quadrant ",Q," (",X1,",",Y1," -> ",X2,",",Y2,") to ",Miner);
     .send(Miner, tell, quadrant(X1,Y1,X2,Y2)).

// Depot is inside this quadrant — skip assigning it to avoid trapping a miner there
+!inform_quad(_, Miner, _)
  <- .print(Miner," is in the depot quadrant — no quadrant assigned.").
