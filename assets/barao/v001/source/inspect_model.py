"""Read the exported GLB, check delivery constraints and render its actual geometry."""
from pathlib import Path
from collections import Counter
from io import BytesIO
import hashlib
import json
import struct
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[1]


def load():
    raw=(ROOT/'barao.glb').read_bytes()
    magic,version,length=struct.unpack_from('<III',raw)
    assert (magic,version,length)==(0x46546c67,2,len(raw))
    size,kind=struct.unpack_from('<II',raw,12)
    assert kind==0x4e4f534a and size%4==0
    doc=json.loads(raw[20:20+size])
    binary_size,binary_kind=struct.unpack_from('<II',raw,20+size)
    assert binary_kind==0x004e4942
    binary=raw[28+size:]
    assert len(binary)==binary_size
    def array(index):
        a=doc['accessors'][index]
        v=doc['bufferViews'][a['bufferView']]
        width={'VEC3':3,'VEC2':2,'SCALAR':1}[a['type']]
        dtype={5126:'<f4',5123:'<u2'}[a['componentType']]
        offset=v.get('byteOffset',0)+a.get('byteOffset',0)
        result=np.frombuffer(binary,dtype=dtype,count=a['count']*width,offset=offset).reshape(-1,width)
        assert offset%4==0 and np.isfinite(result).all()
        if 'min' in a:
            assert np.allclose(result.min(axis=0),a['min']) and np.allclose(result.max(axis=0),a['max'])
        return result
    parts=[]
    for node in doc['nodes']:
        if 'mesh' not in node: continue
        primitive=doc['meshes'][node['mesh']]['primitives'][0]
        attrs=primitive['attributes']
        p=array(attrs['POSITION'])+node['translation']
        n=array(attrs['NORMAL'])
        uv=array(attrs['TEXCOORD_0'])
        tri=array(primitive['indices']).reshape(-1,3).astype(int)
        assert tri.min()>=0 and tri.max()<len(p)
        assert np.allclose(np.linalg.norm(n,axis=1),1,atol=1e-5)
        assert uv.min()>=0 and uv.max()<=1
        cross=np.cross(p[tri[:,1]]-p[tri[:,0]],p[tri[:,2]]-p[tri[:,0]])
        assert (np.linalg.norm(cross,axis=1)>1e-9).all()
        assert (np.einsum('ij,ij->i',cross,n[tri].sum(axis=1))>0).all()
        parts.append(dict(name=node['name'],p=p,n=n,uv=uv,tri=tri,pivot=node['translation'],side=node['extras']['side']))
    v=doc['bufferViews'][doc['images'][0]['bufferView']]
    png=binary[v['byteOffset']:v['byteOffset']+v['byteLength']]
    assert png==(ROOT/'textures/barao_basecolor.png').read_bytes()
    atlas=Image.open(BytesIO(png))
    assert atlas.size==(1024,1024) and atlas.mode=='RGB'
    assert len(doc['materials'])==1 and doc['materials'][0]['alphaMode']=='OPAQUE'
    expected=Counter(['Body','Head','EarL','EarR','Tongue','Tail','LegFL','LegFR','LegBL','LegBR','Eye','Eye'])
    assert Counter(p['name'] for p in parts)==expected
    count=sum(len(p['tri']) for p in parts)
    assert count<=5000
    assert sum(len(p['tri']) for p in parts if p['name']=='Head')<=2000
    points=np.concatenate([p['p'] for p in parts])
    assert abs(points[:,1].min())<1e-6
    assert 3.3<points[:,1].max()<3.7
    assert 4.5<np.ptp(points[:,2])<5.5
    report={'revision':'v001','checks':'passed','triangles':count,
            'pieces':len(parts),'atlas':{'size':[1024,1024],'mode':'RGB','colorSpace':'sRGB','embeddedAndExternalMatch':True},
            'bounds':{'min':points.min(axis=0).tolist(),'max':points.max(axis=0).tolist(),'size':np.ptp(points,axis=0).tolist()},
            'parts':[{'name':p['name'],'side':p['side'],'triangles':len(p['tri']),'pivot':p['pivot']} for p in parts],
            'sha256':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [ROOT/'barao.glb',ROOT/'textures/barao_basecolor.png']},
            'visualReference':'reference/cover.png',
            'notVerified':['Roblox Studio import','animation integration']}
    (ROOT/'validation.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))
    return parts,np.array(atlas)


def render(parts,atlas,direction,filename,label):
    size=960
    forward=np.array(direction,dtype=float)
    forward/=np.linalg.norm(forward)
    up=np.array([0,1,0.0]) if abs(forward[1])<.99 else np.array([0,0,-1.0])
    right=np.cross(up,forward);right/=np.linalg.norm(right)
    up=np.cross(forward,right)
    basis=np.array([right,up,forward])
    points=np.concatenate([p['p'] for p in parts])@basis.T
    lo,hi=points.min(axis=0),points.max(axis=0)
    scale=min((size-160)/(hi[0]-lo[0]),(size-180)/(hi[1]-lo[1]))
    center=(lo+hi)/2
    canvas=np.full((size,size,3),[241,237,229],dtype=np.uint8)
    depth=np.full((size,size),-np.inf)
    light=np.array([-0.4,.8,-.6]);light/=np.linalg.norm(light)
    for part in parts:
        projected=part['p']@basis.T
        projected[:,0]=(projected[:,0]-center[0])*scale+size/2
        projected[:,1]=-(projected[:,1]-center[1])*scale+size/2+15
        for triangle in part['tri']:
            a,b,c=projected[triangle]
            # Render only front faces, as the GLB material is single-sided.
            pa,pb,pc=part['p'][triangle]
            if np.dot(np.cross(pb-pa,pc-pa),forward)<=0:continue
            x0=max(0,int(np.floor(min(a[0],b[0],c[0]))));x1=min(size-1,int(np.ceil(max(a[0],b[0],c[0]))))
            y0=max(0,int(np.floor(min(a[1],b[1],c[1]))));y1=min(size-1,int(np.ceil(max(a[1],b[1],c[1]))))
            if x0>x1 or y0>y1:continue
            yy,xx=np.mgrid[y0:y1+1,x0:x1+1];xx=xx+.5;yy=yy+.5
            den=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
            if abs(den)<1e-10:continue
            w0=((b[1]-c[1])*(xx-c[0])+(c[0]-b[0])*(yy-c[1]))/den
            w1=((c[1]-a[1])*(xx-c[0])+(a[0]-c[0])*(yy-c[1]))/den
            w2=1-w0-w1
            z=w0*a[2]+w1*b[2]+w2*c[2]
            mask=(w0>=-1e-6)&(w1>=-1e-6)&(w2>=-1e-6)&(z>depth[y0:y1+1,x0:x1+1])
            if not mask.any():continue
            weights=np.stack([w0[mask],w1[mask],w2[mask]],axis=1)
            tex=weights@part['uv'][triangle]
            pixels=np.clip((tex*1024).astype(int),0,1023)
            color=atlas[pixels[:,1],pixels[:,0]].astype(float)/255
            normal=weights@part['n'][triangle];normal/=np.linalg.norm(normal,axis=1)[:,None]
            diffuse=np.clip(normal@light,0,1)
            brightness=.55+.45*diffuse
            # Lighting only in preview, never stored in the basecolor texture.
            color=np.power(np.power(color,2.2)*brightness[:,None],1/2.2)
            canvas[y0:y1+1,x0:x1+1][mask]=np.clip(color*255,0,255).astype(np.uint8)
            depth[y0:y1+1,x0:x1+1][mask]=z[mask]
    image=Image.fromarray(canvas)
    d=ImageDraw.Draw(image)
    try: font=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',28)
    except OSError:font=ImageFont.load_default()
    d.text((38,28),f'BARÃO / v001 / {label}',fill='#403426',font=font)
    image.save(ROOT/'previews'/filename)
    return image


if __name__=='__main__':
    parts,atlas=load()
    shots=[((3,2,-5),'perspective.png','perspectiva'),((0,0,-1),'front.png','frente'),
           ((1,0,0),'side.png','lado'),((0,1,0),'top.png','cima'),((3,3,5),'rear.png','costas')]
    images=[render(parts,atlas,*shot) for shot in shots]
    sheet=Image.new('RGB',(1920,1920),'white')
    for i,image in enumerate([images[0],images[4],images[1],images[3]]):sheet.paste(image,((i%2)*960,(i//2)*960))
    sheet.save(ROOT/'previews/contact_sheet.png')
