// Red Leader Agent
// Identical to leader.asl except:
//   - Assigns quadrants to rminer1-4 (not miner1-4)
//   - Waits for 4 bids (5 red miners minus the 1 finder = 4)

/* quadrant allocation */

@rquads[atomic]
+gsize(S,W,H)
  <- .print("Red leader: defining quadrants for sim ", S, " : ", W, "x", H);
     CellH = H div 2;
     +quad(S,1, 0,       0,       W div 2 - 1, CellH - 1);
     +quad(S,2, W div 2, 0,       W - 1,       CellH - 1);
     +quad(S,3, 0,       CellH,   W div 2 - 1, (CellH * 2)-1);
     +quad(S,4, W div 2, CellH,   W - 1,       (CellH * 2)-1);

     !rinform_quad(S,rminer1,1);
     !rinform_quad(S,rminer2,2);
     !rinform_quad(S,rminer3,3);
     !rinform_quad(S,rminer4,4).

+!rinform_quad(S,Miner,Q)
  :  quad(S,Q,X1,Y1,X2,Y2) &
     depot(S,DX,DY) &
     not (DX >= X1 & DX =< X2 & DY >= Y1 & DY =< Y2)
  <- .send(Miner,tell,quadrant(X1,Y1,X2,Y2)).
+!rinform_quad(_,Miner,_)
  <- .print("Red miner ", Miner, " is in the depot quadrant.").


/* Bidding — wait for 4 bids (5 miners, 1 finder doesn't bid) */

+bid(Gold,D,Ag)
  :  .count(bid(Gold,_,_),4)
  <- !rallocate_miner(Gold);
     .abolish(bid(Gold,_,_)).

+!rallocate_miner(Gold)
  <- .findall(op(Dist,A),bid(Gold,Dist,A),LD);
     .min(LD,op(DistCloser,Closer));
     DistCloser < 10000;
     .print("Red leader: gold ",Gold," allocated to ",Closer);
     .broadcast(tell,allocated(Gold,Closer)).
-!rallocate_miner(Gold)
  <- .print("Red leader: could not allocate gold ", Gold).

/* Re-announcement: cancel stale allocation when gold is re-broadcast */
+gold(X,Y)[source(Ag)]
  <- .broadcast(untell, allocated(gold(X,Y),Ag));
     .abolish(gold(_,_)).

/* End of simulation */
+end_of_simulation(S,R)
  <- .print("Red leader -- END ", S, ": ", R);
     .abolish(quad(S,_,_,_,_,_)).
