// smart leader agent

@sectors[atomic]
+gsize(S,W,H)
  <- .print("Smart team starts in roaming mode for simulation ",S," : ",W,"x",H).

+bid(Gold,D,Ag)
  :  .count(bid(Gold,_,_),5)
  <- !allocate_miner(Gold);
     .abolish(bid(Gold,_,_)).

+!allocate_miner(Gold)
  <- .findall(op(Dist,A),bid(Gold,Dist,A),LD);
     .min(LD,op(DistCloser,Closer));
     DistCloser < 10000;
     .print("Gold ",Gold," allocated to ",Closer," with bids ",LD);
     .broadcast(tell,allocated(Gold,Closer)).
-!allocate_miner(Gold)
  <- .print("Could not allocate gold ",Gold).

+gold(X,Y)[source(Ag)]
  <- .broadcast(untell, allocated(gold(X,Y),Ag));
     .abolish(gold(_,_)).
