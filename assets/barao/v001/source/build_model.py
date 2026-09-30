"""Deterministic, editable Barão mesh source. Uses existing NumPy and Pillow only."""
from pathlib import Path
import hashlib
import json
import math
import struct

import numpy as np
from PIL import Image, ImageDraw, PngImagePlugin

ROOT = Path(__file__).resolve().parents[1]
COLORS = ['#C6783A', '#803C20', '#ECC492', '#00943E', '#FFD400',
          '#002776', '#181414', '#601C22', '#F06C8A', '#FFFFFF', '#F6DEBA']


def make_atlas():
    atlas = Image.new('RGB', (1024, 1024), COLORS[0])
    draw = ImageDraw.Draw(atlas)
    for index, color in enumerate(COLORS):
        x, y = (index % 4) * 256, (index // 4) * 256
        draw.rectangle((x, y, x + 255, y + 255), fill=color)
    # Flag tiles have gutters; no baked lighting, shadows or alpha.
    for index in (11, 12, 13):
        tile = Image.new('RGB', (256, 256), COLORS[3])
        d = ImageDraw.Draw(tile)
        d.rectangle((10, 22, 245, 34), fill=COLORS[4])
        d.rectangle((10, 222, 245, 234), fill=COLORS[4])
        d.polygon([(128, 57), (231, 128), (128, 199), (25, 128)], fill=COLORS[4])
        d.ellipse((85, 85, 171, 171), fill=COLORS[5])
        d.arc((67, 110, 193, 177), 205, 335, fill='white', width=7)
        for x, y in [(108, 136), (135, 148), (149, 129), (123, 160), (103, 121)]:
            d.ellipse((x-1, y-1, x+1, y+1), fill='white')
        atlas.paste(tile, ((index % 4)*256, (index // 4)*256))
    # Front of head: cream blaze, broad lower mask; flat pigment only.
    tile = Image.new('RGB', (256, 256), COLORS[0])
    d = ImageDraw.Draw(tile)
    d.rounded_rectangle((106, 9, 150, 190), radius=20, fill=COLORS[2])
    d.ellipse((12, 136, 244, 280), fill=COLORS[2])
    atlas.paste(tile, (512, 768))
    tile = Image.new('RGB', (256, 256), COLORS[3])
    d = ImageDraw.Draw(tile)
    d.rectangle((0, 40, 255, 68), fill=COLORS[4])
    d.rectangle((0, 192, 255, 220), fill=COLORS[4])
    atlas.paste(tile, (768, 768))
    metadata = PngImagePlugin.PngInfo()
    metadata.add(b'sRGB', b'\x00')
    atlas.save(ROOT/'textures/barao_basecolor.png', pnginfo=metadata)
    return atlas


def uv(tile, u=.5, v=.5):
    return [((tile % 4)*256 + 8 + 240*u)/1024,
            ((tile // 4)*256 + 8 + 240*v)/1024]


class Part:
    def __init__(self, name, pivot, side=None):
        self.name, self.pivot, self.side = name, np.array(pivot, float), side
        self.positions, self.normals, self.uvs, self.triangles = [], [], [], []

    def vertex(self, p, n, tex):
        self.positions.append((np.array(p)-self.pivot).tolist())
        self.normals.append(list(n))
        self.uvs.append(tex)
        return len(self.positions)-1

    def triangle(self, a, b, c):
        p = np.array([self.positions[i] for i in (a,b,c)])
        normal = np.cross(p[1]-p[0], p[2]-p[0])
        if np.linalg.norm(normal) < 1e-9:
            return
        if np.dot(normal, np.sum([self.normals[i] for i in (a,b,c)], axis=0)) < 0:
            b, c = c, b
        self.triangles.append([a,b,c])

    def ellipsoid(self, center, radii, tile, segments=16, rings=8, rotation=None):
        rotation = np.eye(3) if rotation is None else rotation
        start = len(self.positions)
        for j in range(rings+1):
            t = math.pi*j/rings
            for i in range(segments+1):
                phi = 2*math.pi*i/segments
                sphere = np.array([math.sin(t)*math.cos(phi), math.cos(t), math.sin(t)*math.sin(phi)])
                n = sphere/np.array(radii)
                n = rotation @ (n/np.linalg.norm(n))
                p = np.array(center) + rotation @ (sphere*np.array(radii))
                self.vertex(p, n, uv(tile))
        for j in range(rings):
            for i in range(segments):
                a = start+j*(segments+1)+i
                b = a+segments+1
                self.triangle(a,b,a+1)
                self.triangle(a+1,b,b+1)

    def box(self, center, size, radius, tile, face_tiles=None):
        half = np.array(size)/2
        core = half-radius
        # Six samples span flat faces and two bevel segments at each edge.
        axes = [np.array([-h, -c-radius*.70710678, -c, c, c+radius*.70710678, h])
                for h,c in zip(half,core)]
        for axis in range(3):
            others = [i for i in range(3) if i != axis]
            for sign in (-1,1):
                face_tile = (face_tiles or {}).get((axis,sign),tile)
                start = len(self.positions)
                for j,b in enumerate(axes[others[1]]):
                    for i,a in enumerate(axes[others[0]]):
                        raw = np.zeros(3)
                        raw[axis], raw[others[0]], raw[others[1]] = sign*half[axis],a,b
                        clamped = np.clip(raw,-core,core)
                        n = raw-clamped
                        n /= np.linalg.norm(n)
                        p = clamped+n*radius+np.array(center)
                        if axis == 0:  # sides: horizontal z, vertical y
                            u, v = (raw[2]/half[2]+1)/2, (1-raw[1]/half[1])/2
                        elif axis == 1:  # back: horizontal x, vertical z
                            u, v = (raw[0]/half[0]+1)/2, (raw[2]/half[2]+1)/2
                        else:
                            u, v = (raw[0]/half[0]+1)/2, (1-raw[1]/half[1])/2
                        tex = uv(face_tile,u,v) if face_tile >= 11 else uv(face_tile)
                        self.vertex(p,n,tex)
                for j in range(5):
                    for i in range(5):
                        a = start+j*6+i
                        self.triangle(a,a+6,a+1)
                        self.triangle(a+1,a+6,a+7)

    def tail(self):
        # Continuous closed tube, one piece with a cream tip.
        centers = [(0,1.85,1.15),(0,2.04,1.38),(0,2.32,1.62),
                   (0,2.61,1.79),(0,2.87,1.82),(0,3.08,1.75)]
        radii = [.20,.245,.255,.235,.18,.045]
        start = len(self.positions)
        for j,(center,radius) in enumerate(zip(centers,radii)):
            tangent = np.array(centers[min(j+1,5)])-np.array(centers[max(j-1,0)])
            tangent /= np.linalg.norm(tangent)
            side = np.cross(tangent,[1,0,0])
            for i in range(12):
                a = math.tau*i/12
                n = np.array([1,0,0])*math.cos(a)+side*math.sin(a)
                self.vertex(np.array(center)+radius*n,n,uv(10 if j>=4 else 0))
        for j in range(5):
            for i in range(12):
                a,b = start+j*12+i,start+j*12+(i+1)%12
                self.triangle(a,b,a+12)
                self.triangle(b,b+12,a+12)
        for j in (0,5):
            tangent=np.array(centers[1])-centers[0] if j==0 else np.array(centers[5])-centers[4]
            tangent=tangent/np.linalg.norm(tangent)*(-1 if j==0 else 1)
            c=self.vertex(centers[j],tangent,uv(0 if j==0 else 10))
            for i in range(12):
                self.triangle(c,start+j*12+i,start+j*12+(i+1)%12)
        # Split the UV seam at the cream tip: interpolating between palette
        # swatches would sample unrelated colors along the tail.
        positions,normals,triangles=self.positions,self.normals,self.triangles
        self.positions,self.normals,self.uvs,self.triangles=[],[],[],[]
        for triangle in triangles:
            tile=10 if min(positions[i][1]+self.pivot[1] for i in triangle)>=2.60 else 0
            indices=[self.vertex(np.array(positions[i])+self.pivot,normals[i],uv(tile)) for i in triangle]
            self.triangle(*indices)


def make_parts():
    parts=[]
    def part(name,pivot,side=None):
        result=Part(name,pivot,side)
        parts.append(result)
        return result
    body=part('Body',(0,1.55,0))
    body.ellipsoid((0,1.52,.65),(.73,.60,.65),0,16,8)
    body.box((0,1.58,-.23),(1.64,1.32,1.95),.28,3,
             {(0,-1):11,(0,1):12,(1,1):13,(2,-1):15})
    head=part('Head',(0,2.2,-1))
    head.box((0,2.75,-1.45),(1.74,1.50,1.52),.36,0,{(2,-1):14})
    # A dark inset cavity framed by the lower jaw and two muzzle lobes.
    head.ellipsoid((0,2.16,-2.25),(.48,.25,.40),2,16,8)
    head.ellipsoid((0,2.26,-2.51),(.43,.235,.18),7,16,8)
    for side in (-1,1):
        head.ellipsoid((side*.23,2.48,-2.36),(.37,.25,.40),10,16,8)
    nose_start=len(head.positions)
    head.ellipsoid((0,2.64,-2.68),(.25,.165,.16),6,16,8)
    # Narrow the bottom into a soft triangular dog nose; transform normals
    # using the inverse transpose of the deformation Jacobian.
    for i in range(nose_start,len(head.positions)):
        x,y,z=np.array(head.positions[i])+head.pivot
        factor=.84+.30*(y-2.64)/.165
        jacobian=np.array([[factor,x*.30/.165,0],[0,1,0],[0,0,1]])
        normal=np.linalg.inv(jacobian).T@head.normals[i]
        head.normals[i]=(normal/np.linalg.norm(normal)).tolist()
        head.positions[i][0]*=factor
    tongue=part('Tongue',(0,2.2,-2.62))
    angle=math.radians(48)
    rotation=np.array([[1,0,0],[0,math.cos(angle),-math.sin(angle)],[0,math.sin(angle),math.cos(angle)]])
    tongue.ellipsoid((0,2.02,-2.77),(.215,.065,.36),8,12,6,rotation)
    for side,label in ((-1,'L'),(1,'R')):
        ear=part('Ear'+label,(side*.86,3.45,-1.45))
        angle=math.radians(side*10)
        rot=np.array([[math.cos(angle),-math.sin(angle),0],[math.sin(angle),math.cos(angle),0],[0,0,1]])
        ear.ellipsoid((side*1.09,2.84,-1.44),(.30,.66,.40),1,16,8,rot)
        eye=part('Eye',(side*.42,2.96,-2.22),label)
        eye.ellipsoid((side*.42,2.96,-2.235),(.195,.225,.13),6,16,8)
        # Both eye components stay in the same mesh; highlight is allowed by brief.
        eye.ellipsoid((side*.42-.05,3.035,-2.350),(.047,.057,.019),9,8,4)
        for z,end in ((-.85,'F'),(.85,'B')):
            leg=part('Leg'+end+label,(side*.5,1.15,z))
            leg.ellipsoid((side*.5,.73,z),(.245,.60,.25),0,12,6)
            leg.ellipsoid((side*.5,.19,z-.085),(.30,.19,.355),2,12,6)
            if end=='F':
                leg.ellipsoid((side*.5,.99,z),(.282,.19,.285),4,12,6)
    part('Tail',(0,1.85,1.15)).tail()
    return parts


def export_glb(parts):
    doc={'asset':{'version':'2.0','generator':'BlocoPuff Barão v001'},
         'scene':0,'scenes':[{'nodes':[0]}],
         'nodes':[{'name':'Barao','children':list(range(1,len(parts)+1)),
                   'extras':{'up':'+Y','forward':'-Z','origin':'ground between paws','revision':'v001'}}],
         'meshes':[],'accessors':[],'bufferViews':[],
         'materials':[{'name':'BaraoAtlas','alphaMode':'OPAQUE','doubleSided':False,
                       'pbrMetallicRoughness':{'baseColorTexture':{'index':0},'metallicFactor':0,'roughnessFactor':.82}}],
         'textures':[{'source':0,'sampler':0}],
         'samplers':[{'magFilter':9729,'minFilter':9987,'wrapS':33071,'wrapT':33071}]}
    binary=bytearray()
    def view(data,target=None):
        binary.extend(b'\0'*((-len(binary))%4))
        result={'buffer':0,'byteOffset':len(binary),'byteLength':len(data)}
        if target: result['target']=target
        doc['bufferViews'].append(result)
        binary.extend(data)
        return len(doc['bufferViews'])-1
    def accessor(data,dtype,kind,component,target,bounds=False):
        array=np.array(data,dtype=dtype)
        obj={'bufferView':view(array.tobytes(),target),'componentType':component,'count':len(array),'type':kind}
        if bounds:
            obj.update(min=array.min(axis=0).tolist(),max=array.max(axis=0).tolist())
        doc['accessors'].append(obj)
        return len(doc['accessors'])-1
    for i,part in enumerate(parts):
        attributes={'POSITION':accessor(part.positions,'<f4','VEC3',5126,34962,True),
                    'NORMAL':accessor(part.normals,'<f4','VEC3',5126,34962),
                    'TEXCOORD_0':accessor(part.uvs,'<f4','VEC2',5126,34962)}
        indices=accessor(np.array(part.triangles).flatten(),'<u2','SCALAR',5123,34963)
        doc['meshes'].append({'name':part.name,'primitives':[{'attributes':attributes,'indices':indices,'material':0,'mode':4}]})
        doc['nodes'].append({'name':part.name,'mesh':i,'translation':part.pivot.tolist(),
                             'extras':{'side':part.side,'pivotSpace':'model','animationGroup':'Head' if part.name=='Eye' else part.name}})
    doc['images']=[{'bufferView':view((ROOT/'textures/barao_basecolor.png').read_bytes()),'mimeType':'image/png'}]
    doc['buffers']=[{'byteLength':len(binary)}]
    data=json.dumps(doc,separators=(',',':')).encode()
    data+=b' '*((-len(data))%4)
    binary.extend(b'\0'*((-len(binary))%4))
    result=struct.pack('<III',0x46546C67,2,12+8+len(data)+8+len(binary))
    result+=struct.pack('<II',len(data),0x4E4F534A)+data
    result+=struct.pack('<II',len(binary),0x004E4942)+binary
    (ROOT/'barao.glb').write_bytes(result)
    (ROOT/'pivots.json').write_text(json.dumps({'root':[0,0,0],'up':'+Y','forward':'-Z',
        'parts':[{'node':i+1,'name':p.name,'side':p.side,'pivot':p.pivot.tolist()} for i,p in enumerate(parts)]},indent=2)+'\n')
    print(f'Exported {len(parts)} meshes, {sum(len(p.triangles) for p in parts)} triangles.')


if __name__=='__main__':
    make_atlas()
    export_glb(make_parts())
