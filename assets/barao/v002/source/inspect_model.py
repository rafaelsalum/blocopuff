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
        width={'VEC4':4,'VEC3':3,'VEC2':2,'SCALAR':1}[a['type']]
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
        tangent=array(attrs['TANGENT'])
        assert np.allclose(np.linalg.norm(tangent[:,:3],axis=1),1,atol=1e-5)
        assert np.allclose(np.sum(tangent[:,:3]*n,axis=1),0,atol=1e-5)
        assert np.isin(tangent[:,3],[-1,1]).all()
        uv=array(attrs['TEXCOORD_0'])
        tri=array(primitive['indices']).reshape(-1,3).astype(int)
        assert tri.min()>=0 and tri.max()<len(p)
        assert np.allclose(np.linalg.norm(n,axis=1),1,atol=1e-5)
        assert uv.min()>=0 and uv.max()<=1
        cross=np.cross(p[tri[:,1]]-p[tri[:,0]],p[tri[:,2]]-p[tri[:,0]])
        assert (np.linalg.norm(cross,axis=1)>1e-9).all()
        assert (np.einsum('ij,ij->i',cross,n[tri].sum(axis=1))>0).all()
        parts.append(dict(name=node['name'],p=p,n=n,tangent=tangent,uv=uv,tri=tri,pivot=node['translation'],side=node['extras']['side']))
    v=doc['bufferViews'][doc['images'][0]['bufferView']]
    png=binary[v['byteOffset']:v['byteOffset']+v['byteLength']]
    assert png==(ROOT/'textures/barao_basecolor.png').read_bytes()
    atlas=Image.open(BytesIO(png))
    assert atlas.size==(1024,1024) and atlas.mode=='RGB'
    assert atlas.info.get('srgb')==0
    for index,name in enumerate(('basecolor','normal','orm')):
        view=doc['bufferViews'][doc['images'][index]['bufferView']]
        embedded=binary[view['byteOffset']:view['byteOffset']+view['byteLength']]
        assert embedded==(ROOT/f'textures/barao_{name}.png').read_bytes()
        texture=Image.open(BytesIO(embedded))
        assert texture.size==(1024,1024) and texture.mode=='RGB'
    roughness=Image.open(ROOT/'textures/barao_roughness.png')
    assert roughness.size==(1024,1024) and roughness.mode=='RGB'
    orm=np.array(Image.open(ROOT/'textures/barao_orm.png'))
    assert np.array_equal(orm[:,:,1],np.array(roughness)[:,:,0])
    assert (orm[:,:,2]==0).all()
    assert len(doc['materials'])==1 and doc['materials'][0]['alphaMode']=='OPAQUE'
    material=doc['materials'][0]
    assert material['normalTexture']['index']==1
    assert material['pbrMetallicRoughness']['metallicRoughnessTexture']['index']==2
    pivots=json.loads((ROOT/'pivots.json').read_text())
    assert len(pivots['parts'])==len(parts)
    for part,record in zip(parts,pivots['parts']):
        assert part['name']==record['name'] and part['pivot']==record['pivot']
    assert doc['nodes'][0]['children']==list(range(1,13))
    assert doc['nodes'][0].get('translation',[0,0,0])==[0,0,0]
    expected=Counter(['Body','Head','EarL','EarR','Tongue','Tail','LegFL','LegFR','LegBL','LegBR','Eye','Eye'])
    assert Counter(p['name'] for p in parts)==expected
    count=sum(len(p['tri']) for p in parts)
    assert count<=5000
    assert sum(len(p['tri']) for p in parts if p['name']=='Head')<=2000
    points=np.concatenate([p['p'] for p in parts])
    assert abs(points[:,1].min())<1e-6
    assert 3.3<points[:,1].max()<3.7
    assert 4.5<np.ptp(points[:,2])<5.5
    report={'revision':'v002','checks':'passed','triangles':count,
            'pieces':len(parts),'atlas':{'size':[1024,1024],'mode':'RGB','colorSpace':'sRGB','embeddedAndExternalMatch':True},
            'bounds':{'min':points.min(axis=0).tolist(),'max':points.max(axis=0).tolist(),'size':np.ptp(points,axis=0).tolist()},
            'parts':[{'name':p['name'],'side':p['side'],'triangles':len(p['tri']),'pivot':p['pivot']} for p in parts],
            'sha256':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest()
                      for p in [ROOT/'barao.glb',*sorted((ROOT/'textures').glob('*.png'))]},
            'pbrMaps':['basecolor (sRGB)','normal (linear)','roughness (linear)','ORM (linear; G=roughness, B=metallic)'],
            'scope':'Local structural and numeric validation; not an official glTF validator or a Roblox import test',
            'visualReference':'reference/cover.png',
            'notVerified':['Roblox Studio import','animation integration']}
    (ROOT/'validation.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))
    return parts,np.array(atlas)


if __name__=='__main__':
    from render_preview import Renderer
    parts,atlas=load()
    renderer=Renderer(parts,atlas,ROOT)
    shots=[((3,2,-5),'perspective.png','perspectiva'),((0,0,-1),'front.png','frente'),
           ((1,0,0),'side.png','lado'),((0,1,0),'top.png','cima'),((3,3,5),'rear.png','costas')]
    images=[renderer.render(*shot) for shot in shots]
    sheet=Image.new('RGB',(1920,1920),'white')
    for i,image in enumerate([images[0],images[4],images[1],images[3]]):sheet.paste(image,((i%2)*960,(i//2)*960))
    sheet.save(ROOT/'previews/contact_sheet.png')
