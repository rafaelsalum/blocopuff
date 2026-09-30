"""Small surface builders for the editable Barão model (Y up, forward -Z)."""
import math
import numpy as np


def normalize(value):
    value = np.asarray(value, float)
    return value / max(np.linalg.norm(value), 1e-12)


class Part:
    def __init__(self, name, pivot, side=None):
        self.name, self.pivot, self.side = name, np.array(pivot, float), side
        self.positions, self.normals, self.uvs, self.triangles = [], [], [], []

    def vertex(self, p, n, uv):
        self.positions.append((np.asarray(p)-self.pivot).tolist())
        self.normals.append(normalize(n).tolist())
        self.uvs.append(list(uv))
        return len(self.positions)-1

    def triangle(self, a, b, c):
        p = np.array([self.positions[i] for i in (a,b,c)])
        n = np.cross(p[1]-p[0], p[2]-p[0])
        if np.linalg.norm(n) < 1e-9:
            return
        if np.dot(n, np.sum([self.normals[i] for i in (a,b,c)],axis=0)) < 0:
            b,c = c,b
        self.triangles.append([a,b,c])

    def surface(self, sample, texture, columns, rows, outward):
        start = len(self.positions)
        for j in range(rows+1):
            v=j/rows
            for i in range(columns+1):
                u=i/columns
                p=np.array(sample(u,v))
                # Derivatives evaluated just inside poles to avoid zero normals.
                t=np.clip(v,1e-5,1-1e-5)
                du=np.array(sample(u+1e-5,t))-sample(u-1e-5,t)
                dv=np.array(sample(u,t+1e-5))-sample(u,t-1e-5)
                n=normalize(np.cross(du,dv))
                if np.dot(n,outward(p))<0:n=-n
                self.vertex(p,n,texture(u,v,p))
        for j in range(rows):
            for i in range(columns):
                a=start+j*(columns+1)+i
                self.triangle(a,a+columns+1,a+1)
                self.triangle(a+1,a+columns+1,a+columns+2)

    def ellipsoid(self, center, radii, texture, segments=16, rings=8, rotation=None, exponent=1):
        center=np.array(center,float)
        rotation=np.eye(3) if rotation is None else rotation
        def power(x):return np.sign(x)*abs(x)**exponent
        def sample(u,v):
            theta=math.pi*v;phi=math.tau*u
            p=np.array([power(math.sin(theta))*power(math.cos(phi)),power(math.cos(theta)),
                        power(math.sin(theta))*power(math.sin(phi))])*radii
            return center+rotation@p
        self.surface(sample,texture,segments,rings,lambda p:p-center)

    def box(self, center, size, radius, texture, face_texture=None, taper=0):
        half=np.array(size)/2;core=half-radius;center=np.array(center,float)
        axes=[np.array([-h,-c-radius*.8660254,-c-radius*.5,-c,c,c+radius*.5,c+radius*.8660254,h]) for h,c in zip(half,core)]
        for axis in range(3):
            others=[i for i in range(3) if i!=axis]
            for sign in (-1,1):
                start=len(self.positions)
                mapping=(face_texture or {}).get((axis,sign),texture)
                for b in axes[others[1]]:
                    for a in axes[others[0]]:
                        raw=np.zeros(3);raw[axis]=sign*half[axis]
                        raw[others[0]],raw[others[1]]=a,b
                        c=np.clip(raw,-core,core)
                        n=normalize(raw-c);p=c+n*radius
                        if taper:
                            factor=1-taper*(p[2]/half[2]+1)/2
                            jac=np.array([[factor,0,-p[0]*taper/(2*half[2])],[0,1,0],[0,0,1]])
                            p[0]*=factor;n=normalize(np.linalg.inv(jac).T@n)
                        if axis==0:u,v=(raw[2]/half[2]+1)/2,(1-raw[1]/half[1])/2
                        elif axis==1:u,v=(raw[0]/half[0]+1)/2,(raw[2]/half[2]+1)/2
                        else:u,v=(raw[0]/half[0]+1)/2,(1-raw[1]/half[1])/2
                        self.vertex(p+center,n,mapping(u,v,p+center))
                for j in range(7):
                    for i in range(7):
                        a=start+j*8+i
                        self.triangle(a,a+8,a+1);self.triangle(a+1,a+8,a+9)

    def loft(self, sections, texture, segments=16, exponent=1):
        """Closed rings with explicit lateral/depth axes, including capped ends."""
        start=len(self.positions)
        centers=[np.array(s[0]) for s in sections]
        for j,(center,width,thickness,lateral,depth) in enumerate(sections):
            lateral,depth=normalize(lateral),normalize(depth)
            for i in range(segments+1):
                a=math.tau*i/segments
                x=np.sign(math.cos(a))*abs(math.cos(a))**exponent
                z=np.sign(math.sin(a))*abs(math.sin(a))**exponent
                p=np.array(center)+lateral*width*x+depth*thickness*z
                n=normalize(lateral*x+depth*z)
                self.vertex(p,n,texture(i/segments,j/(len(sections)-1),p))
        for j in range(len(sections)-1):
            for i in range(segments):
                a=start+j*(segments+1)+i;b=a+segments+1
                self.triangle(a,b,a+1);self.triangle(a+1,b,b+1)
        self.smooth_normals(start)
        for j in (0,len(sections)-1):
            n=normalize(centers[0]-centers[1] if j==0 else centers[-1]-centers[-2])
            n=normalize(np.cross(sections[j][3],sections[j][4]))*np.sign(np.dot(np.cross(sections[j][3],sections[j][4]),n))
            c=self.vertex(centers[j],n,texture(.5,j/(len(sections)-1),centers[j]))
            ring=[]
            for i in range(segments+1):
                original=start+j*(segments+1)+i
                ring.append(self.vertex(np.array(self.positions[original])+self.pivot,n,self.uvs[original]))
            for i in range(segments):
                a,b=ring[i],ring[i+1]
                cross=np.cross(np.array(self.positions[a])-self.positions[c],np.array(self.positions[b])-self.positions[c])
                if np.dot(cross,n)<0:a,b=b,a
                self.triangles.append([c,a,b])

    def smooth_normals(self,start=0):
        """Area-weighted smoothing, welding duplicate vertices at UV seams."""
        sums={}
        keys={i:tuple(np.round(p,6)) for i,p in enumerate(self.positions) if i>=start}
        for triangle in self.triangles:
            if min(triangle)<start:continue
            a,b,c=np.array([self.positions[i] for i in triangle])
            n=np.cross(b-a,c-a)
            for i in triangle:sums[keys[i]]=sums.get(keys[i],np.zeros(3))+n
        for i,key in keys.items():
            if key in sums:self.normals[i]=normalize(sums[key]).tolist()

    def tube(self, points, radius, texture, segments=6):
        sections=[]
        for i,p in enumerate(points):
            tangent=normalize(np.array(points[min(i+1,len(points)-1)])-points[max(0,i-1)])
            side=normalize(np.cross(tangent,[0,0,1]))
            depth=normalize(np.cross(tangent,side))
            sections.append((p,radius,radius,side,depth))
        self.loft(sections,texture,segments)
