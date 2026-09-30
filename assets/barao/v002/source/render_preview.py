"""Offline previews of exported mesh data with shadow maps and PBR texture inputs."""
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFont


def unit(v):
    v=np.asarray(v,float)
    return v/np.maximum(np.linalg.norm(v,axis=-1,keepdims=True),1e-12)


def basis_for(direction):
    forward=unit(direction)
    up=np.array([0.,1,0]) if abs(forward[1])<.99 else np.array([0.,0,-1])
    right=unit(np.cross(up,forward))
    return np.array([right,np.cross(forward,right),forward])


def raster(triangle,size):
    a,b,c=triangle
    x0=max(0,int(np.floor(min(a[0],b[0],c[0]))));x1=min(size-1,int(np.ceil(max(a[0],b[0],c[0]))))
    y0=max(0,int(np.floor(min(a[1],b[1],c[1]))));y1=min(size-1,int(np.ceil(max(a[1],b[1],c[1]))))
    if x0>x1 or y0>y1:return None
    yy,xx=np.mgrid[y0:y1+1,x0:x1+1];xx=xx+.5;yy=yy+.5
    den=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
    if abs(den)<1e-10:return None
    w0=((b[1]-c[1])*(xx-c[0])+(c[0]-b[0])*(yy-c[1]))/den
    w1=((c[1]-a[1])*(xx-c[0])+(a[0]-c[0])*(yy-c[1]))/den
    w2=1-w0-w1
    return x0,x1,y0,y1,w0,w1,w2


class Renderer:
    def __init__(self,parts,atlas,root):
        self.parts,self.atlas,self.root=parts,atlas,root
        self.normal=np.array(Image.open(root/'textures/barao_normal.png'),dtype=float)/255*2-1
        self.rough=np.array(Image.open(root/'textures/barao_roughness.png'),dtype=float)[:,:,0]/255
        self.light=unit([-3,5,-4]);self.fill=unit([4,2,1])
        self.shadow_basis=basis_for(self.light)
        points=np.concatenate([p['p'] for p in parts])@self.shadow_basis.T
        lo,hi=points.min(axis=0),points.max(axis=0)
        self.shadow_center=(lo+hi)/2
        self.shadow_scale=1850/max(hi[0]-lo[0],hi[1]-lo[1])
        self.shadow=np.full((2048,2048),-np.inf)
        for part in parts:
            projected=self.project_shadow(part['p'])
            for ids in part['tri']:
                triangle=projected[ids]
                r=raster(triangle,2048)
                if r is None:continue
                x0,x1,y0,y1,w0,w1,w2=r
                z=w0*triangle[0,2]+w1*triangle[1,2]+w2*triangle[2,2]
                region=self.shadow[y0:y1+1,x0:x1+1]
                mask=(w0>=0)&(w1>=0)&(w2>=0)
                region[mask]=np.maximum(region[mask],z[mask])

    def project_shadow(self,p):
        p=p@self.shadow_basis.T
        p[:,0]=(p[:,0]-self.shadow_center[0])*self.shadow_scale+1024
        p[:,1]=(p[:,1]-self.shadow_center[1])*self.shadow_scale+1024
        return p

    def visibility(self,p):
        q=self.project_shadow(p)
        x,y=q[:,0].astype(int),q[:,1].astype(int)
        visible=np.zeros(len(p))
        for dx,dy in [(-3,-3),(0,-3),(3,-3),(-3,0),(0,0),(3,0),(-3,3),(0,3),(3,3)]:
            values=self.shadow[np.clip(y+dy,0,2047),np.clip(x+dx,0,2047)]
            visible+=(q[:,2]+.012>=values)
        return visible/9

    def render(self,direction,filename,label):
        size=1440;basis=basis_for(direction);view=basis[2]
        points=np.concatenate([p['p'] for p in self.parts])@basis.T
        lo,hi=points.min(axis=0),points.max(axis=0);center=(lo+hi)/2
        scale=min((size-235)/(hi[0]-lo[0]),(size-260)/(hi[1]-lo[1]))
        def project(p):
            q=p@basis.T
            q[:,0]=(q[:,0]-center[0])*scale+size/2
            q[:,1]=-(q[:,1]-center[1])*scale+size/2+30
            return q
        canvas=np.full((size,size,3),[235,231,222],dtype=np.uint8)
        depth=np.full((size,size),-np.inf)
        # Ground is preview staging only and is not added to the model.
        if view[1]>.01:
            yy,xx=np.mgrid[:size,:size]
            horizontal=(xx-size/2)/scale+center[0]
            vertical=-(yy-size/2-30)/scale+center[1]
            ray_start=horizontal[:,:,None]*basis[0]+vertical[:,:,None]*basis[1]
            t=-ray_start[:,:,1]/view[1]
            world=ray_start+t[:,:,None]*view
            flat=world.reshape(-1,3)
            visibility=np.concatenate([self.visibility(flat[i:i+50000]) for i in range(0,len(flat),50000)]).reshape(size,size)
            canvas=np.uint8(canvas.astype(float)*(.75+.25*visibility[:,:,None]))
        halfway=unit(self.light+view)
        for part in self.parts:
            projected=project(part['p'])
            for ids in part['tri']:
                pa,pb,pc=part['p'][ids]
                if np.dot(np.cross(pb-pa,pc-pa),view)<=0:continue
                triangle=projected[ids];r=raster(triangle,size)
                if r is None:continue
                x0,x1,y0,y1,w0,w1,w2=r
                z=w0*triangle[0,2]+w1*triangle[1,2]+w2*triangle[2,2]
                region=depth[y0:y1+1,x0:x1+1]
                mask=(w0>=-1e-6)&(w1>=-1e-6)&(w2>=-1e-6)&(z>region)
                if not mask.any():continue
                weights=np.stack([w0[mask],w1[mask],w2[mask]],axis=1)
                tex=weights@part['uv'][ids]
                pixels=np.clip((tex*1024).astype(int),0,1023)
                color=self.atlas[pixels[:,1],pixels[:,0]].astype(float)/255
                n=unit(weights@part['n'][ids]);world=weights@part['p'][ids]
                # Use the tangent frame stored in the delivered GLB.
                tangent=weights@part['tangent'][ids,:3]
                tangent=unit(tangent-n*np.sum(n*tangent,axis=1)[:,None])
                handedness=np.where(weights@part['tangent'][ids,3]<0,-1,1)
                bitangent=np.cross(n,tangent)*handedness[:,None]
                sampled=self.normal[pixels[:,1],pixels[:,0]]
                n=unit(tangent*sampled[:,0,None]+bitangent*sampled[:,1,None]+n*sampled[:,2,None])
                roughness=self.rough[pixels[:,1],pixels[:,0]]
                vis=self.visibility(world)
                lambert=np.clip(n@self.light,0,1)
                fill=np.clip(n@self.fill,0,1)
                exposure=.25+.85*lambert*vis+.18*fill
                linear=np.power(color,2.2)*exposure[:,None]
                # Broad softbox response depends on exported material roughness.
                exponent=np.maximum(3,2/(roughness+.16)**4-2)
                spec=np.power(np.clip(n@halfway,0,1),exponent)*(1-roughness)**2*.50*vis
                linear+=spec[:,None]
                color=np.power(np.clip(linear,0,1),1/2.2)
                canvas[y0:y1+1,x0:x1+1][mask]=np.uint8(color*255)
                region[mask]=z[mask]
        image=Image.fromarray(canvas).resize((960,960),Image.Resampling.LANCZOS)
        d=ImageDraw.Draw(image)
        try:font=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',25)
        except OSError:font=ImageFont.load_default()
        d.text((35,25),f'BARÃO / v002 / {label}',fill='#403426',font=font)
        image.save(self.root/'previews'/filename)
        return image
