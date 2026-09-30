from pathlib import Path
import json
import struct
import numpy as np
ROOT=Path(__file__).resolve().parents[1]


def tangents(part):
    p=np.array(part.positions);uv=np.array(part.uvs);n=np.array(part.normals)
    t=np.zeros_like(p);b=np.zeros_like(p)
    for ids in part.triangles:
        a,c,d=ids
        e1,e2=p[c]-p[a],p[d]-p[a]
        q1,q2=uv[c]-uv[a],uv[d]-uv[a]
        determinant=q1[0]*q2[1]-q1[1]*q2[0]
        if abs(determinant)<1e-12:continue
        tangent=(e1*q2[1]-e2*q1[1])/determinant
        bitangent=(e2*q1[0]-e1*q2[0])/determinant
        for i in ids:t[i]+=tangent;b[i]+=bitangent
    t-=n*np.sum(n*t,axis=1)[:,None]
    for i in range(len(t)):
        if np.linalg.norm(t[i])<1e-10:
            t[i]=np.cross(n[i],[0,1,0] if abs(n[i,1])<.9 else [1,0,0])
    t/=np.linalg.norm(t,axis=1)[:,None]
    sign=np.where(np.sum(np.cross(n,t)*b,axis=1)<0,-1,1)
    return np.column_stack([t,sign])


def export_glb(parts):
    doc={'asset':{'version':'2.0','generator':'BlocoPuff Barão v002'},
         'scene':0,'scenes':[{'nodes':[0]}],
         'nodes':[{'name':'Barao','children':list(range(1,len(parts)+1)),
                   'extras':{'up':'+Y','forward':'-Z','origin':'ground between paws','revision':'v002'}}],
         'meshes':[],'accessors':[],'bufferViews':[],
         'materials':[{'name':'BaraoAtlas','alphaMode':'OPAQUE','doubleSided':False,'normalTexture':{'index':1,'scale':1},
                       'pbrMetallicRoughness':{'baseColorTexture':{'index':0},'metallicFactor':0,'roughnessFactor':1,'metallicRoughnessTexture':{'index':2}}}],
         'textures':[{'source':i,'sampler':0} for i in range(3)],
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
                    'TANGENT':accessor(tangents(part),'<f4','VEC4',5126,34962),
                    'TEXCOORD_0':accessor(part.uvs,'<f4','VEC2',5126,34962)}
        indices=accessor(np.array(part.triangles).flatten(),'<u2','SCALAR',5123,34963)
        doc['meshes'].append({'name':part.name,'primitives':[{'attributes':attributes,'indices':indices,'material':0,'mode':4}]})
        doc['nodes'].append({'name':part.name,'mesh':i,'translation':part.pivot.tolist(),
                             'extras':{'side':part.side,'pivotSpace':'model','animationGroup':'Head' if part.name=='Eye' else part.name}})
    doc['images']=[{'bufferView':view((ROOT/f'textures/barao_{name}.png').read_bytes()),'mimeType':'image/png'} for name in ('basecolor','normal','orm')]
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

