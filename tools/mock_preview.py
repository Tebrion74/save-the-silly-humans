import numpy as np, sys
from PIL import Image
T=32
A={k:Image.open(f'assets/tiles/stsh_{k}_atlas.png').convert('RGBA') for k in ('ground','dirt','path','forest','water')}
W,H=24,16
rng=np.random.default_rng(3)
yy,xx=np.mgrid[0:H+1,0:W+1]
water=((xx-17)**2/9+(yy-5)**2/5)<1
water|=((xx-5)**2/4+(yy-12)**2/3)<1
forest=((xx-6)**2/30+(yy-4)**2/12)<1
path=(abs(yy-9)<1)|((abs(xx-12)<1)&(yy<9))
dirt=((xx-20)**2/6+(yy-12)**2/4)<1
img=Image.new('RGBA',(W*T,H*T))
def tile(a,cx,cy): return A[a].crop((cx*T,cy*T,cx*T+T,cy*T+T))
for y in range(H):
  for x in range(W):
    g=rng.integers(0,32); img.alpha_composite(tile('ground',g%16,g//16),(x*T,y*T))
for name,vg in (('forest',forest),('dirt',dirt),('path',path),('water',water)):
  for y in range(H):
    for x in range(W):
      m=int(vg[y,x])*1+int(vg[y,x+1])*2+int(vg[y+1,x])*4+int(vg[y+1,x+1])*8
      if m==0: continue
      if name=='water':
        c=((m%4)*4, m//4)
      else:
        c=(m,0) if m!=15 else (rng.integers(0,4),1)
      img.alpha_composite(tile(name,*c),(x*T,y*T))
img.save('/tmp/mock.png')
img.resize((W*T*2//2,H*T*2//2)).save('/tmp/mock_s.png')
img.crop((320,0,320+400,260)).resize((800,520),0).save('/tmp/mock_zoom.png')
