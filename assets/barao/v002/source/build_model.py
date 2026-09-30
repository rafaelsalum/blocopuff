"""Barão v002: shaped ears, fitted jersey, expressive muzzle and continuous paws."""
from pathlib import Path
import math
import numpy as np
from mesh import Part,normalize
from textures import create,mapped,projected,uv
from export_glb import export_glb

ROOT=Path(__file__).resolve().parents[1]


def rotation_z(angle):
    c,s=math.cos(angle),math.sin(angle)
    return np.array([[c,-s,0],[s,c,0],[0,0,1]])


def parts():
    result=[]
    def new(name,pivot,side=None):
        p=Part(name,pivot,side);result.append(p);return p

    body=new('Body',(0,1.55,0))
    body.ellipsoid((0,1.55,.67),(.67,.55,.63),mapped('fur'),16,6)
    body.box((0,1.59,-.26),(1.62,1.24,1.96),.49,mapped('sleeve'),
             {(0,-1):mapped('side'),(0,1):mapped('side'),(1,1):mapped('back'),(2,-1):mapped('chest')},taper=.11)
    # Neck rises into the head. Its visible edge forms a fitted green collar.
    body.ellipsoid((0,2.00,-.91),(.55,.33,.43),mapped('sleeve'),12,5)

    head=new('Head',(0,2.20,-1.00))
    head.box((0,2.70,-1.47),(1.80,1.60,1.46),.38,mapped('fur'),
             {(2,-1):mapped('face'),(1,1):lambda u,v,p:uv('face',u,v*.13)})
    # Smile cavity: upper lip dips under the nose, corners lift toward cheeks.
    outline=[]
    for i in range(11):
        x=-.565+1.13*i/10
        y=2.48-.15*(1-(x/.565)**2)
        outline.append((x,y,-2.40+.07*abs(x/.565)))
    for i in range(1,10):
        a=math.pi*i/10
        outline.append((.565*math.cos(a),2.48-.46*math.sin(a),-2.39))
    center=(0,2.27,-2.31)
    front=head.vertex(center,[0,0,-1],uv('mouth',.5,.5))
    boundary=[head.vertex(p,[0,0,-1],uv('mouth',.5,.5)) for p in outline]
    for i in range(len(boundary)):head.triangle(front,boundary[i],boundary[(i+1)%len(boundary)])
    # Solid cheek shell surrounding the cavity. The shell extends back into
    # the head, so the smile has volume and remains correct in side views.
    start=len(head.positions)
    shell=[]
    for expansion,zoffset in [(1,0),(1.12,.025),(1.22,.12),(1.12,.30)]:
        ring=[]
        for x,y,z in outline:
            p=(x*expansion,2.29+(y-2.29)*expansion,z+zoffset)
            ring.append(head.vertex(p,[x*.3,(y-2.29)*.3,-1],
                                    uv('cream',(x/.70+1)/2,(2.70-y)/.9)))
        shell.append(ring)
    for a,b in zip(shell,shell[1:]):
        for i in range(len(a)):
            j=(i+1)%len(a)
            head.triangles.extend([[a[i],b[i],a[j]],[a[j],b[i],b[j]]])
    head.smooth_normals(start)
    # The lip is real geometry; the atlas contains no painted cavity shadow.
    head.tube(outline+[outline[0]],.021,lambda u,v,p:uv('mouth',.5,.5),4)
    for side in (-1,1):
        head.ellipsoid((side*.255,2.49,-2.405),(.335,.235,.265),mapped('cream'),20,8,
                       rotation_z(side*.12),exponent=.88)
    # Rounded triangular nose, narrower bottom, with nostrils in its own UV patch.
    start=len(head.positions)
    nose_center=np.array((0,2.65,-2.65))
    head.ellipsoid(nose_center,(.255,.175,.12),
                   projected('nose',(-.26,.26),(2.475,2.825)),20,8)
    for i in range(start,len(head.positions)):
        p=np.array(head.positions[i])+head.pivot
        factor=.84+.38*(p[1]-nose_center[1])/.175
        jac=np.array([[factor,p[0]*.38/.175,0],[0,1,0],[0,0,1]])
        n=normalize(np.linalg.inv(jac).T@head.normals[i])
        head.normals[i]=n.tolist();head.positions[i][0]*=factor

    for side,label in ((-1,'L'),(1,'R')):
        # A narrow root folds outward over the crown, then widens into a soft lobe.
        ear=new('Ear'+label,(side*.83,3.35,-1.30))
        def ear_center(t):
            return np.array([side*(.71+.52*math.sin(t*math.pi*.69)),3.42-1.04*t,
                             -1.25-.43*math.sin(t*math.pi*.66)])
        def ear_sample(u,v):
            fullness=abs(math.sin(math.pi*v))**.62
            a=math.tau*u
            return ear_center(v)+np.array([.35*fullness*math.cos(a),0,.14*fullness*math.sin(a)])
        ear.surface(ear_sample,mapped('ear'),16,9,
                    lambda p:p-ear_center(np.clip((3.42-p[1])/1.04,0,1)))
        eye=new('Eye',(side*.43,2.96,-2.205),label)
        eye.ellipsoid((side*.43,2.96,-2.225),(.17,.225,.095),
                      projected('eye',(side*.43-.18,side*.43+.18),(2.73,3.19)),16,8,
                      rotation_z(-side*.09))
        for z,end in ((-.85,'F'),(.85,'B')):
            leg=new('Leg'+end+label,(side*.50,1.15,z))
            # Continuous rounded-square foot, ankle and shoulder; flat sole at y=0.
            profiles=[(.0,.235,.25,-.085),(.055,.29,.32,-.10),(.19,.30,.35,-.11),
                      (.31,.27,.29,-.075),(.39,.22,.22,0),(.74,.23,.22,0),
                      (1.05,.265,.245,0),(1.46,.15,.16,0)]
            sections=[((side*.50,y,z+offset),w,t,(1,0,0),(0,0,1)) for y,w,t,offset in profiles]
            def leg_uv(u,v,p):
                return uv('leg',u,1-p[1]/1.30)
            leg.loft(sections,leg_uv,12,exponent=.64)
            if end=='F':
                sleeve=[((side*.50,y,z),w,t,(1,0,0),(0,0,1))
                        for y,w,t in [(1.29,.255,.245),(1.19,.30,.28),(.91,.295,.28),(.85,.28,.265)]]
                leg.loft(sleeve,mapped('sleeve'),12,exponent=.76)

    tongue=new('Tongue',(0,2.27,-2.43))
    tongue_sections=[((0,2.28,-2.44),.105,.045),((0,2.23,-2.56),.18,.052),
                     ((0,2.11,-2.66),.225,.054),((0,1.96,-2.70),.235,.052),
                     ((0,1.84,-2.68),.205,.045),((0,1.78,-2.65),.12,.032),
                     ((0,1.77,-2.64),.025,.013)]
    tongue.loft([(c,w,t,(1,0,0),(0,.15,1)) for c,w,t in tongue_sections],
                lambda u,v,p:uv('tongue',(p[0]+.24)/.48,v),12)

    tail=new('Tail',(0,1.85,1.15))
    tail_profile=[(1.85,1.13,.14),(2.00,1.31,.20),(2.22,1.55,.235),
                  (2.47,1.72,.245),(2.70,1.83,.23),(2.90,1.84,.19),
                  (3.07,1.77,.13),(3.16,1.69,.055),(3.18,1.65,.015)]
    sections=[]
    for i,(y,z,r) in enumerate(tail_profile):
        prev=tail_profile[max(0,i-1)];nxt=tail_profile[min(len(tail_profile)-1,i+1)]
        tangent=normalize([0,nxt[0]-prev[0],nxt[1]-prev[1]])
        sections.append(((0,y,z),r,r,[1,0,0],np.cross(tangent,[1,0,0])))
    tail.loft(sections,lambda u,v,p:uv('tail',u,1-v),12)
    return result


if __name__=='__main__':
    create(ROOT)
    export_glb(parts())
