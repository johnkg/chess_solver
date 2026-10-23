# Line-by-line Python mirror of docs/draft-engine/position.dart (logic check only)
E,P,N,B,R,Q,K=0,1,2,3,4,5,6
W,Bk=0,1
KN=[(1,2),(2,1),(2,-1),(1,-2),(-1,-2),(-2,-1),(-2,1),(-1,2)]
KG=[(1,0),(1,1),(0,1),(-1,1),(-1,0),(-1,-1),(0,-1),(1,-1)]
BD=[(1,1),(1,-1),(-1,1),(-1,-1)]
RD=[(1,0),(-1,0),(0,1),(0,-1)]
def mk(t,c): return t|(c<<3)
def pt(p): return p&7
def pc(p): return p>>3
CH={'P':mk(P,W),'N':mk(N,W),'B':mk(B,W),'R':mk(R,W),'Q':mk(Q,W),'K':mk(K,W),
    'p':mk(P,Bk),'n':mk(N,Bk),'b':mk(B,Bk),'r':mk(R,Bk),'q':mk(Q,Bk),'k':mk(K,Bk)}
def sq(r,f): return r*8+f
class Pos:
    def __init__(s,fen):
        p=fen.split(); s.sq=[0]*64
        for i,row in enumerate(p[0].split('/')):
            r=7-i; f=0
            for ch in row:
                if ch.isdigit(): f+=int(ch)
                else: s.sq[sq(r,f)]=CH[ch]; f+=1
        s.turn=W if p[1]=='w' else Bk
        s.cast=0
        for ch in (p[2] if len(p)>2 else '-'):
            s.cast|={'K':1,'Q':2,'k':4,'q':8}.get(ch,0)
        s.ep=-1
        if len(p)>3 and p[3]!='-': s.ep=(int(p[3][1])-1)*8+ord(p[3][0])-97
    def attacked(s,x,by):
        r,f=x>>3,x&7
        pr=r-1 if by==W else r+1
        if 0<=pr<8:
            pp=mk(P,by)
            if f>0 and s.sq[sq(pr,f-1)]==pp: return True
            if f<7 and s.sq[sq(pr,f+1)]==pp: return True
        for d in KN:
            nr,nf=r+d[0],f+d[1]
            if 0<=nr<8 and 0<=nf<8 and s.sq[sq(nr,nf)]==mk(N,by): return True
        for d in KG:
            nr,nf=r+d[0],f+d[1]
            if 0<=nr<8 and 0<=nf<8 and s.sq[sq(nr,nf)]==mk(K,by): return True
        for dirs,a in ((BD,B),(RD,R)):
            for d in dirs:
                nr,nf=r+d[0],f+d[1]
                while 0<=nr<8 and 0<=nf<8:
                    p=s.sq[sq(nr,nf)]
                    if p:
                        if p==mk(a,by) or p==mk(Q,by): return True
                        break
                    nr+=d[0]; nf+=d[1]
        return False
    def pseudo(s):
        m=[]; t=s.turn
        for x in range(64):
            p=s.sq[x]
            if not p or pc(p)!=t: continue
            ty=pt(p); r,f=x>>3,x&7
            if ty==P:
                d=1 if t==W else -1; sr=1 if t==W else 6; lr=7 if t==W else 0
                def add(to,fl):
                    if to>>3==lr:
                        for pr in (Q,R,B,N): m.append((x,to,pr,0))
                    else: m.append((x,to,0,fl))
                if not(0<=r+d<8): continue
                one=sq(r+d,f)
                if s.sq[one]==0:
                    add(one,0)
                    if r==sr and s.sq[sq(r+2*d,f)]==0: add(sq(r+2*d,f),1)
                for df in (-1,1):
                    nf=f+df
                    if not 0<=nf<8: continue
                    to=sq(r+d,nf); tg=s.sq[to]
                    if tg and pc(tg)!=t: add(to,0)
                    elif tg==0 and to==s.ep: m.append((x,to,0,4))
            elif ty in (N,K):
                for d in (KN if ty==N else KG):
                    nr,nf=r+d[0],f+d[1]
                    if 0<=nr<8 and 0<=nf<8:
                        to=sq(nr,nf); tg=s.sq[to]
                        if tg==0 or pc(tg)!=t: m.append((x,to,0,0))
                if ty==K: s.castle(m)
            else:
                dirs=(BD if ty==B else RD if ty==R else BD+RD)
                for d in dirs:
                    nr,nf=r+d[0],f+d[1]
                    while 0<=nr<8 and 0<=nf<8:
                        to=sq(nr,nf); tg=s.sq[to]
                        if tg==0: m.append((x,to,0,0))
                        else:
                            if pc(tg)!=t: m.append((x,to,0,0))
                            break
                        nr+=d[0]; nf+=d[1]
        return m
    def castle(s,m):
        b=0 if s.turn==W else 56; th=1-s.turn
        if s.sq[b+4]!=mk(K,s.turn): return
        ks=1 if s.turn==W else 4; qs=2 if s.turn==W else 8; rk=mk(R,s.turn)
        if s.cast&ks and s.sq[b+7]==rk and s.sq[b+5]==0 and s.sq[b+6]==0 and not s.attacked(b+4,th) and not s.attacked(b+5,th) and not s.attacked(b+6,th):
            m.append((b+4,b+6,0,2))
        if s.cast&qs and s.sq[b]==rk and s.sq[b+1]==0 and s.sq[b+2]==0 and s.sq[b+3]==0 and not s.attacked(b+4,th) and not s.attacked(b+3,th) and not s.attacked(b+2,th):
            m.append((b+4,b+2,0,3))
    def make(s,mv):
        fr,to,pr,fl=mv; n=Pos.__new__(Pos); n.sq=s.sq[:]; t=s.turn
        p=n.sq[fr]; n.sq[to]=mk(pr,t) if pr else p; n.sq[fr]=0
        if fl==4: n.sq[to-8 if t==W else to+8]=0
        elif fl==2: n.sq[fr+3]=0; n.sq[fr+1]=mk(R,t)
        elif fl==3: n.sq[fr-4]=0; n.sq[fr-1]=mk(R,t)
        c=s.cast
        if pt(p)==K: c&= ~3 if t==W else ~12
        for x in (fr,to):
            if x==0: c&=~2
            if x==7: c&=~1
            if x==56: c&=~8
            if x==63: c&=~4
        n.cast=c; n.ep=(fr+to)>>1 if fl==1 else -1; n.turn=1-t
        return n
    def ksq(s,c):
        return s.sq.index(mk(K,c)) if mk(K,c) in s.sq else -1
    def legal(s):
        out=[]
        for mv in s.pseudo():
            n=s.make(mv); k=n.ksq(s.turn)
            if k<0 or not n.attacked(k,1-s.turn): out.append(mv)
        return out
    def perft(s,d):
        if d==0: return 1
        ms=s.legal()
        if d==1: return len(ms)
        return sum(s.make(m).perft(d-1) for m in ms)
def main():
    T=[("start","rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",[20,400,8902,197281]),
    ("kiwipete","r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",[48,2039,97862]),
    ("pos3","8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1",[14,191,2812,43238]),
    ("pos4","r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1",[6,264,9467]),
    ("pos5","rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8",[44,1486,62379])]
    ok=True
    for name,fen,exp in T:
        pos=Pos(fen)
        got=[pos.perft(i+1) for i in range(len(exp))]
        print(name,got,"OK" if got==exp else f"MISMATCH expected {exp}")
        ok&=got==exp
    print("ALL OK" if ok else "FAIL")

if __name__=="__main__":
    main()
