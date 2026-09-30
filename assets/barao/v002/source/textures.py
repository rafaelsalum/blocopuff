"""Painted pigment, short-fur microdetail and textile maps; no baked lighting."""
from pathlib import Path
import math
import random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, PngImagePlugin

REGIONS={'face':(0,0,512,512),'fur':(512,0,256,256),'ear':(768,0,256,256),
         'cream':(512,256,256,256),'nose':(768,256,256,256),
         'side':(0,512,256,256),'back':(256,512,256,256),'chest':(512,512,256,256),
         'mouth':(768,512,128,128),'eye':(896,512,128,128),
         'tongue':(768,640,256,128),'leg':(0,768,256,256),'paw':(256,768,256,256),
         'sleeve':(512,768,256,256),'tail':(768,768,256,256)}
COLORS={'fur':(198,120,58),'ear':(128,60,32),'cream':(236,196,146),
        'green':(0,148,62),'yellow':(255,212,0),'blue':(0,39,118)}


def uv(name,u,v):
    x,y,w,h=REGIONS[name]
    return [(x+6+(w-12)*np.clip(u,0,1))/1024,(y+6+(h-12)*np.clip(v,0,1))/1024]


def mapped(name):
    return lambda u,v,p:uv(name,u,v)


def projected(name,xrange,yrange):
    return lambda u,v,p:uv(name,(p[0]-xrange[0])/(xrange[1]-xrange[0]),
                          (yrange[1]-p[1])/(yrange[1]-yrange[0]))


def create(root):
    rng=np.random.default_rng(2741);random.seed(2741)
    color=Image.new('RGB',(1024,1024),COLORS['fur'])
    normal=Image.new('RGB',(1024,1024),(128,128,255))
    rough=Image.new('RGB',(1024,1024),(220,220,220))
    orm=Image.new('RGB',(1024,1024),(255,220,0))
    for name,(x,y,w,h) in REGIONS.items():
        base=COLORS.get(name,COLORS['fur'])
        if name in ('side','back','chest','sleeve'):base=COLORS['green']
        if name=='face':base=COLORS['fur']
        if name=='paw':base=COLORS['cream']
        if name=='mouth':base=(32,9,13)
        if name=='eye':base=(18,13,10)
        if name=='nose':base=(33,23,20)
        if name=='tongue':base=(237,99,131)
        tile=Image.new('RGB',(w,h),base);d=ImageDraw.Draw(tile)
        if name=='face':
            # Broad cheek mask and a blaze that reaches the crown.
            d.polygon([(232,0),(284,0),(289,85),(281,145),(276,218),
                       (292,283),(230,295),(220,214),(228,140),(225,80)],fill=COLORS['cream'])
            d.ellipse((-40,260,552,676),fill=COLORS['cream'])
            # Short eyebrows, deliberately separate from eyeballs.
            for x0 in (120,328):
                d.arc((x0,88,x0+62,126),195,310,fill=(87,43,25),width=8)
        if name in ('side','back'):
            d.rectangle((0,34,255,56),fill=COLORS['yellow'])
            d.rectangle((0,202,255,224),fill=COLORS['yellow'])
            # Rectangular flag, diamond, globe and curved white band.
            d.polygon([(128,71),(219,128),(128,185),(37,128)],fill=COLORS['yellow'])
            scale=.64 if name=='side' else 1.17
            tx=lambda x:128+(x-128)*scale
            d.ellipse((tx(93),93,tx(163),163),fill=COLORS['blue'])
            d.arc((tx(75),111,tx(175),170),207,331,fill=(255,253,235),width=5)
            for a,b in [(109,129),(123,139),(141,144),(117,149),(149,126),(131,153)]:
                d.ellipse((tx(a)-1,b-1,tx(a)+1,b+1),fill=(250,248,228))
            # Flat seam pigment, not a painted shadow.
            for a in (14,241):d.line((a,8,a,248),fill=(0,122,51),width=1)
        if name=='chest':
            d.rectangle((0,34,255,56),fill=COLORS['yellow'])
            d.rectangle((0,202,255,224),fill=COLORS['yellow'])
            d.line([(99,0),(128,65),(157,0)],fill=(0,86,43),width=12)
            d.line((128,63,128,116),fill=(0,98,44),width=3)
            for yy in (79,99):d.ellipse((125,yy,131,yy+6),fill=(8,58,30))
        if name=='sleeve':
            d.rectangle((0,140,w,208),fill=COLORS['yellow'])
            d.rectangle((0,237,w,h),fill=(0,108,47))
        if name=='leg':
            d.rectangle((0,205,w,h),fill=COLORS['cream'])
        if name=='tail':
            border=[(i,int(80+8*math.sin(i*.23)+4*math.cos(i*.5))) for i in range(w)]
            d.polygon([(0,0),(w,0)]+list(reversed(border)),fill=COLORS['cream'])
        if name=='nose':
            for xx in (74,182):
                d.ellipse((xx-17,143,xx+13,165),fill=(7,5,5))
            d.line([(128,190),(126,234)],fill=(15,9,9),width=3)
        if name=='eye':
            d.ellipse((27,23,64,58),fill=(255,255,248))
            d.ellipse((69,54,82,67),fill=(239,246,248))
        if name=='tongue':
            d.line([(126,10),(127,45),(130,76),(128,95)],fill=(203,64,98),width=3)
        # Per-material surface microstructure. Only pigment and height, no light.
        height=Image.new('L',(w,h),128);hd=ImageDraw.Draw(height)
        if name in ('face','fur','ear','cream','leg','paw','tail'):
            for _ in range(w*h//9):
                xx=random.randrange(w);yy=random.randrange(h)
                length=random.randrange(2,7)
                dx=random.choice([-2,-1,0,1,2])
                delta=random.choice([-7,-4,3,6])
                c=tuple(int(np.clip(a+delta,0,255)) for a in tile.getpixel((xx,yy)))
                d.line((xx,yy,xx+dx,yy+length),fill=c,width=1)
                hd.line((xx,yy,xx+dx,yy+length),fill=random.randrange(107,150),width=1)
        elif name in ('side','back','chest','sleeve'):
            arr=np.array(tile,dtype=float)
            yy,xx=np.mgrid[:h,:w]
            weave=((xx%3==0).astype(float)-(yy%3==0).astype(float))*2
            tile=Image.fromarray(np.uint8(np.clip(arr+weave[:,:,None],0,255)))
            height=Image.fromarray(np.uint8(128+weave*5))
        elif name=='nose':
            heights=np.clip(rng.normal(128,9,(h,w)),85,170).astype('uint8')
            height=Image.fromarray(heights).filter(ImageFilter.GaussianBlur(.5))
        elif name=='tongue':
            hd.line([(126,10),(127,45),(130,76),(128,95)],fill=92,width=4)
            height=height.filter(ImageFilter.GaussianBlur(1.1))
        arr=np.array(tile,dtype=float)
        if name not in ('eye','mouth'):
            arr+=rng.normal(0,.7,(h,w,1))
        color.paste(Image.fromarray(np.uint8(np.clip(arr,0,255))),(x,y))
        height_array=np.array(height,dtype=float)/255
        dy,dx=np.gradient(height_array)
        strength=1.7 if name in ('eye','nose','tongue') else 1.0
        vectors=np.stack([-dx*strength,-dy*strength,np.ones((h,w))],axis=-1)
        vectors/=np.linalg.norm(vectors,axis=-1,keepdims=True)
        normal.paste(Image.fromarray(np.uint8(np.clip((vectors*.5+.5)*255,0,255))),(x,y))
        value={'eye':38,'nose':78,'tongue':115,'mouth':195}.get(name,217)
        r=np.full((h,w),value,dtype=np.uint8)
        rough.paste(Image.fromarray(r).convert('RGB'),(x,y))
        orm.paste(Image.fromarray(np.stack([np.full_like(r,255),r,np.zeros_like(r)],axis=-1)),(x,y))
    info=PngImagePlugin.PngInfo();info.add(b'sRGB',b'\0')
    color.save(root/'textures/barao_basecolor.png',pnginfo=info)
    normal.save(root/'textures/barao_normal.png')
    rough.save(root/'textures/barao_roughness.png')
    orm.save(root/'textures/barao_orm.png')
