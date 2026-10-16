"""Genera los 9-slice de botón (assets/ui/btn_<a|b|c>_<estado>.png), 12x12: A hierro, B filo de sangre, C hueso."""
from PIL import Image
N=12
def new(bg): return Image.new("RGBA",(N,N),bg+(255,))
def px(im,pts,c):
    for x,y in pts: im.putpixel((x,y),c+(255,))
def cut(im,k):  # esquinas recortadas k px (diagonal)
    for x0,y0,dx,dy in [(0,0,1,1),(N-1,0,-1,1),(0,N-1,1,-1),(N-1,N-1,-1,-1)]:
        for i in range(k):
            for j in range(k-i): im.putpixel((x0+dx*i,y0+dy*j),(0,0,0,0))
def frame(im,c,k=0):
    for i in range(N):
        px(im,[(i,0),(i,N-1),(0,i),(N-1,i)],c)
def A(st):  # hierro con remaches
    bg,bd,ln,stud={"normal":((20,14,24),(96,32,44),(44,22,38),(190,170,130)),
      "hover":((54,14,28),(200,60,64),(90,24,40),(240,215,160)),
      "pressed":((86,16,34),(240,90,80),(60,12,26),(255,235,190))}[st]
    im=new(bg); frame(im,bd)
    for i in range(2,N-2): px(im,[(i,1),(i,N-2),(1,i),(N-2,i)],ln)
    px(im,[(2,2),(N-3,2),(2,N-3),(N-3,N-3)],stud); cut(im,1); return im
def B(st):  # filo de sangre
    bg,bd,ac={"normal":((14,9,18),(58,20,34),(130,18,40)),
      "hover":((52,10,26),(150,40,56),(230,50,70)),
      "pressed":((84,14,32),(220,80,80),(255,110,100))}[st]
    im=new(bg); frame(im,bd)
    for y in range(3,N-3): px(im,[(1,y),(2,y),(N-2,y),(N-3,y)],ac)
    cut(im,2); return im
def C(st):  # hueso con escuadras
    bg,bd,br={"normal":((24,16,30),(70,50,60),(200,180,140)),
      "hover":((62,14,30),(150,70,70),(240,215,160)),
      "pressed":((92,18,36),(210,100,90),(255,235,190))}[st]
    im=new(bg); frame(im,bd)
    for x0,y0,dx,dy in [(0,0,1,1),(N-1,0,-1,1),(0,N-1,1,-1),(N-1,N-1,-1,-1)]:
        for i in range(4): px(im,[(x0+dx*i,y0),(x0,y0+dy*i)],br)
    return im
for name,f in [("a",A),("b",B),("c",C)]:
    for st in ("normal","hover","pressed"): f(st).save(f"assets/ui/btn_{name}_{st}.png")
