#!/usr/bin/python

# This is your main conversion from 3d files to javascript code with passage tubes
# The main bit does the output for the ground window, as c# but it lear from the svxscale
# but it should be generalized to handle convertdmptotunnelvrjson instead

import re, datetime, time, math, os, sys, json, tempfile
from collections import namedtuple


dump3dexe = '"C:\\Program Files (x86)\\Survex\\dump3d.exe"'
if sys.platform[:5] == "linux":
    dump3dexe = "dump3d"

class P3(namedtuple('P3', ['x', 'y', 'z'])):
    __slots__ = ()
    def __new__(self, x, y, z):
        return super(P3, self).__new__(self, float(x), float(y), float(z))
    def __repr__(self):
        return "P3(%s, %s, %s)" % (self.x, self.y, self.z)
    def __add__(self, a):
        return P3(self.x + a.x, self.y + a.y, self.z + a.z)
    def __sub__(self, a):
        return P3(self.x - a.x, self.y - a.y, self.z - a.z)
    def __mul__(self, a):
        return P3(self.x*a, self.y*a, self.z*a)
    def __neg__(self):
        return P3(-self.x, -self.y, -self.z)
    def __rmul__(self, a):
        raise TypeError
    def Lensq(self):
        return self.x*self.x + self.y*self.y + self.z*self.z
    def Len(self):
        return math.sqrt(self.Lensq())
    def LenLZ(self):
        return math.sqrt(self.x*self.x + self.y*self.y)
        
    def assertlen1(self):
        assert abs(self.Len() - 1.0) < 0.0001
        return True
        
    @staticmethod
    def Dot(a, b):
        return a.x*b.x + a.y*b.y + a.z*b.z

    @staticmethod
    def Cross(a, b):
        return P3(a.y*b.z - b.y*a.z, -a.x*b.z + b.x*a.z, a.x*b.y - b.x*a.y)

    @staticmethod
    def ZNorm(v):
        ln = v.Len()
        if ln == 0.0:  
            ln = 1.0
        return P3(v.x/ln, v.y/ln, v.z/ln)


"""
# parses the output of dump3d.c in the survex codebase
TITLE "wolf"
DATE "@1471364805"
DATE_NUMERIC 1471364805
CS +init=epsg:26717 +no_defs
VERSION 8
SEPARATOR '.'
--
MOVE 515727.86 4127857.76 596.80
LINE 515729.21 4127855.33 599.44 [eg3] STYLE=NORMAL 2005.10.15
ERROR_INFO #legs 1, len 3.78m, E 0.70 H 0.61 V 0.82
NODE 512036.63 4127340.23 505.51 [eg7.12] SURFACE UNDERGROUND ENTRANCE
XSECT 0.40 0.40 0.10 0.40 [leckfell.allmarblesteps.wetroute.sidewinder2.006]
XSECT_END
STOP
"""

# nodeflags in  [SURFACE, UNDERGROUND, ENTRANCE, EXPORTED, FIXED, ANON]
# linestyles in [NORMAL DIVING CARTESIAN CYLPOLAR NOSURVEY]
# lineflags in  [SURFACE DUPLICATE SPLAY]

def vtri(a, b, c):
    vb, vc = b - a, c - a
    n = P3.Cross(vc, vb)
    nlen = n.Len()
    if nlen == 0:
        return 0
    theight = P3.Dot(n, a)/nlen
    tarea = nlen/2
    return theight*tarea/3

def vquad(q0, q1, q2, q3):
    return vtri(q0, q1, q2) + vtri(q0, q2, q3)


class DMP3d:
    def __init__(self, lines):
        self.title = ""
        self.cs = None
        self.datenumeric = 0
        self.headdate = None
        
        self.nodepmap = { }   # { p: ([names], [flagsconsolidated] }  
        self.nodes = [ ]      # [ (p, name, [flags]) ]   (not strictly necessary, except to get entrance name before flagconsolidation)
        self.lines = [ ]      # [ (prevp, p, name, style, [flags], date) ]
        self.xsects = [ [ ] ] # [ [ (name, lrud) ] ]
        self.nmapnodes = { }  # { name: p } (derived from nodepmap, needed for xsects)

        binheader = True
        prevp = None

        for l in lines:
            if binheader:
                if l.strip() == '--':
                    binheader = False
                else:
                    c, v = l.split(" ", 1)
                    if c == "TITLE":
                        self.title = v.strip().strip('"')
                    elif c == "DATE_NUMERIC":
                        self.datenumeric = int(v)
                        t = time.gmtime(int(v))
                        self.headdate = datetime.datetime(*t[:6])
                    elif c == "CS":
                        self.cs = v.strip()  # proj = pyproj.Proj(v)
                continue
                
            ls = l.split()
            if ls[0] == "ERROR_INFO":
                continue
            elif ls[0] == "STOP":
                break
            elif ls[0] == "NODE":
                p = P3(float(ls[1]), float(ls[2]), float(ls[3]))
                s = ls[4]
                assert s[0] == "[" and s[-1] == "]", ls
                if p not in self.nodepmap:
                    self.nodepmap[p] = ([ ], set()) 
                self.nodepmap[p][0].append(s[1:-1])
                self.nodepmap[p][1].update(set(ls[5:]))  # consolidate shared flags

                self.nodes.append((p, s[1:-1], set(ls[5:])))

            elif ls[0] == "MOVE":
                prevp = P3(float(ls[1]), float(ls[2]), float(ls[3]))
            elif ls[0] == "LINE":
                p = P3(float(ls[1]), float(ls[2]), float(ls[3]))
                s = ls[4]
                assert s[0] == "[" and s[-1] == "]", ls
                style = ""
                ddate = ""
                n = 5
                if n < len(ls) and ls[n][:6] == "STYLE=":
                    style = ls[5][6:]
                    n += 1
                flags = [ ]
                while n < len(ls) and ls[n] in ["SURFACE", "DUPLICATE", "SPLAY"]:
                    flags.append(ls[n])
                    n += 1
                if n < len(ls) and re.match("\d\d\d\d\.\d\d\.\d\d", ls[n]):
                        ddate = datetime.datetime.strptime(ls[n][:10], "%Y.%m.%d")  # ignoring date ranges
                        n += 1
                assert len(ls) == n, ls
                self.lines.append((prevp, p, s[1:-1], style, flags, ddate))  # strip[] from [survey.block]
                prevp = p
            elif ls[0] == "XSECT":
                s = ls[5]
                assert s[0] == "[" and s[-1] == "]", ls
                lrud = (float(ls[1]), float(ls[2]), float(ls[3]), float(ls[4]))
                self.xsects[-1].append((s[1:-1], lrud))
            elif ls[0] == "XSECT_END":
                self.xsects.append([])
                
        if not self.xsects[-1]:
            self.xsects.pop()

        for p, v in self.nodepmap.items():
            for na in v[0]:
                self.nmapnodes[na] = p
                
        
    # ported from GfxCore::SkinPassage in survex
    # [take care with hacking this code down as it gets out of sync with the shifted xc which is actually output; maybe don't bother, just do a complete rewrite]
    def GetXSectionQuadHedronP(self, xsect):
        assert len(xsect) >= 2
        resquads = [ ]
        resxcs = [ ]
        cumushift = 0
        nmapnodes = self.nmapnodes
        
        U0, U1, U2, U3 = P3(0.0,0.0,0.0), P3(0.0,0.0,0.0), P3(0.0,0.0,0.0), P3(0.0,0.0,0.0)
        last_right = P3(1.0, 0.0, 0.0)
        right = P3(0,0,0)
        up = P3(0,0,0)
        up_v = P3(0.0, 0.0, 1.0)
        for i in range(len(xsect)):
            z_pitch_adjust = 0.0
            cover_end = False
            shift = 0
            if i == 0:
                leg_v = nmapnodes[xsect[1][0]] - nmapnodes[xsect[0][0]]
                right = P3.Cross(leg_v, up_v)
                if right.Lensq() == 0:  
                    right = last_right
                    up = up_v
                else:
                    last_right = right
                    up = up_v   # a mistake?
                cover_end = True
            elif i == len(xsect)-1:
                leg_v = nmapnodes[xsect[-1][0]] - nmapnodes[xsect[-2][0]]
                right = P3.Cross(leg_v, up_v)
                if (right.Lensq() == 0):
                    right = P3(last_right.x, last_right.y, 0.0)
                    up = up_v
                else:
                    last_right = right
                    up = up_v
                cover_end = True
            else:
                leg1_v = nmapnodes[xsect[i][0]] - nmapnodes[xsect[i-1][0]]
                leg2_v = nmapnodes[xsect[i+1][0]] - nmapnodes[xsect[i][0]]
                r1 = P3.ZNorm(P3.Cross(leg1_v, up_v))
                r2 = P3.ZNorm(P3.Cross(leg2_v, up_v))
                right = r1 + r2
                if (right.Lensq() == 0):
                    right = last_right
                if r1.Lensq() == 0:
                    n = P3.ZNorm(leg1_v)
                    z_pitch_adjust = n.z
                    up = up_v
                    shift = 0
                    maxdotp = 0.0
                    right = P3.ZNorm(right)
                    up = P3.ZNorm(up)
                    vec = up - right
                    UU = [U0, U1, U2, U3]
                    for orient in range(4):
                        tmp = UU[orient] - nmapnodes[xsect[i-1][0]]
                        tmp = P3.ZNorm(tmp)
                        dotp = P3.Dot(vec, tmp)
                        if (dotp > maxdotp):
                            maxdotp = dotp
                            shift = orient
                    if shift:
                        if shift != 2:
                            temp = UU[0]
                            UU[0] = UU[shift];
                            UU[shift] = UU[2];
                            UU[2] = UU[shift ^ 2];
                            UU[shift ^ 2] = temp;
                        else:
                            UU0, UU2 = UU2, UU0
                            UU1, UU3 = UU3, UU1
                    U0, U1, U2, U3 = UU
                elif r2.Lensq() == 0:
                    n = P3.ZNorm(leg2_v)
                    z_pitch_adjust = n.z
                    up = up_v
                else:
                    up = up_v
            last_right = right
            right = P3.ZNorm(right)
            up = P3.ZNorm(up)
            if (z_pitch_adjust != 0):
                up = up + P3(0, 0, abs(z_pitch_adjust))
            l, r = abs(xsect[i][1][0]), abs(xsect[i][1][1])
            u, d = abs(xsect[i][1][2]), abs(xsect[i][1][3])
            pt_v = nmapnodes[xsect[i][0]]
            v0 = pt_v - right*l + up*u
            v1 = pt_v + right*r + up*u
            v2 = pt_v + right*r - up*d
            v3 = pt_v - right*l - up*d
            if cover_end and i == 0:
                resquads.append((v0, v1, v2, v3))
            if i != 0:
                resquads.append((v0, v1, U1, U0))
                resquads.append((v1, v2, U2, U1))
                resquads.append((v2, v3, U3, U2))
                resquads.append((v3, v0, U0, U3))
            if cover_end and i != 0:
                resquads.append((v3, v2, v1, v0))
            if shift:
                cumushift += 4-shift
            vs = [v0,v1,v2,v3]
            resxcs.append([vs[(i+cumushift)%4]  for i in range(4)])
            U0, U1, U2, U3 = v0, v1, v2, v3
        return resquads, resxcs

    def GetXSectionQuadHedron(self, xsect):
        return self.GetXSectionQuadHedronP(xsect)[0]

    def GetXSectionFacts(self, xsect):
        nmapnodes = self.nmapnodes
        xcareasum = 0
        leng = 0
        for i in range(len(xsect)):
            l, r = abs(xsect[i][1][0]), abs(xsect[i][1][1])
            u, d = abs(xsect[i][1][2]), abs(xsect[i][1][3])
            lback = (nmapnodes[xsect[i][0]] - nmapnodes[xsect[i-1][0]]).Len() if i != 0 else 0
            lfore = (nmapnodes[xsect[i+1][0]] - nmapnodes[xsect[i][0]]).Len() if i != len(xsect)-1 else 0
            xcareasum += (l+r)*(u+d) * (lback+lfore)*0.5
            leng += lback
        if leng == 0:
            return (0,0,0)
        xvol = sum(vquad(q0, q1, q2, q3)  for q0, q1, q2, q3 in self.GetXSectionQuadHedron(xsect))
        return (leng, xvol, xvol/leng, xcareasum/leng)

    def PassagesVolume(self):
        volplus, volminus = 0, 0
        for xsect in self.xsects:
            if len(xsect) < 2:
                continue
            xvol = sum(vquad(q0, q1, q2, q3)  for q0, q1, q2, q3 in self.GetXSectionQuadHedron(xsect))
            if xvol > 0:
                volplus += xvol
            else:
                volminus += xvol
        return volplus, volminus

    def PassagesLength(self):
        centerlineleng = sum((line[0] - line[1]).Len()  for line in self.lines  if "SURFACE" not in line[4] and "SPLAY" not in line[4] and  "DUPLICATE" not in line[4])
        xsecseqleng = 0
        for xsect in self.xsects:
            if len(xsect) < 2:
                continue
            for i in range(1, len(xsect)):
                leg_v = self.nmapnodes[xsect[i][0]] - self.nmapnodes[xsect[i-1][0]]
                xsecseqleng += leg_v.Len()
        return centerlineleng, xsecseqleng

    def printreport(self, fname):
        centrelineleng, xsectseqleng = self.PassagesLength()
        volplus, volminus = self.PassagesVolume()
        print("File: %s Title: %s processed: %s" % (fname, self.title, self.headdate))
        print("Survey contains %d survey stations, joined by %d legs." % (len(self.nodepmap), len(self.lines)))
        vlines = [(line[0] - line[1])  for line in self.lines  if "SURFACE" not in line[4] and "SPLAY" not in line[4] and  "DUPLICATE" not in line[4]]
        print("Total length of undeground survey legs = %dm." % (sum(v.Len()  for v in vlines)))
        print("Plan length %dm, Vertical length %dm" % (sum(v.LenLZ()  for v in vlines), sum(abs(v.z)  for v in vlines)))
        unodes = [(k, v[0][0])  for k, v in self.nodepmap.items()  if "UNDERGROUND" in v[1]]
        for rdesc, ri in [("Vertical", 2), ("North-South", 1), ("East-West", 0)]:
            nodemin, nodemax = min(unodes, key=lambda X: X[0][ri]), max(unodes, key=lambda X: X[0][ri])
            print("%s range = %dm (from %s at %dm to %s at %dm" % (rdesc, nodemax[0][ri] - nodemin[0][ri], nodemax[1], nodemax[0][ri], nodemin[1], nodemin[0][ri]))
        print("xsectpassageleng=%dm passagevol=%dm^3" % (xsectseqleng, volplus))
        
        print("\nSurvey tree:")
        snodes = [ name.split(".")  for name in self.nmapnodes  if name ]
        snodes.sort(key=lambda X: (X[:-2], "", X[-2:]))  # get shorter sequences in front
        scnodes = [ ]
        for snode in snodes:
            if not scnodes or scnodes[-1][0] != snode[:-1]:
                scnodes.append((snode[:-1], [ ]))
            scnodes[-1][1].append(snode[-1])

        res = [ ]
        prevk = [ ]
        for k, v in scnodes:
            if not prevk or prevk[:-1] != k[:-1]:
                lprevk = prevk[:]
                while lprevk and ((len(lprevk) > len(k)) or (lprevk[-1] != k[len(lprevk)-1])):
                    lprevk.pop()
                while len(lprevk) < len(k) - 2:
                    lprevk.append(k[len(lprevk)])
                    res.append("\n%s%s:" % ("  "*(len(lprevk)-1), lprevk[-1]))
                if len(k) >= 2:
                    res.append("\n%s%s:" % ("  "*(len(k)-2), k[-2]))
            res.append(" %s[%d]" % (k[-1] if k else "root", len(v)))
            prevk = k
        print("".join(res))


def allocatesortblocknames(leglines, xsects):
    # uses leglines instead of self.lines as it's been thinned of the surface legs
    blocknames = set(leg[2]  for leg in leglines)
    blocknames.update(xsect[0][0].rsplit(".", 1)[0]  for xsect in xsects)
    blocknames = list(blocknames)
    blocknames.sort(key=lambda X: X.split("."))
    blocknameindex = dict((name, i)  for i, name in enumerate(blocknames))

    Dblockspanningxsects = [ xsect  for xsect in xsects  if len(set(x[0].rsplit(".", 1)[0]  for x in xsect)) != 1 ]
    assert not Dblockspanningxsects, Dblockspanningxsects[0][0]

    leglines.sort(key=lambda X: blocknameindex[X[2]])
    xsects.sort(key=lambda X: blocknameindex[X[0][0].rsplit(".", 1)[0]])

    legblockstarts, xsectblockstarts = [ ], [ ]
    iline, ixsect = 0, 0
    for blockname in blocknames+["------"]:
        legblockstarts.append(iline)
        xsectblockstarts.append(ixsect)
        while iline < len(leglines) and leglines[iline][2] == blockname:
            iline += 1
        assert iline == len(leglines) or leglines[iline][2].split(".") > blockname.split(".")
        while ixsect < len(xsects) and xsects[ixsect][0][0].rsplit(".", 1)[0] == blockname:
            ixsect += 1
        assert ixsect == len(xsects) or xsects[ixsect][0][0].split(".")[:-1] > blockname.split(".")
        
    assert legblockstarts[-1] == len(leglines), (legblockstarts, len(leglines))
    assert xsectblockstarts[-1] == len(xsects)
    return blocknames, legblockstarts, xsectblockstarts

def findallocateentrects(blocknames, legnodesdict, nodes):
    def namedottree(names):
        res = set(names)
        for name in names:
            sname = name.split(".")
            while len(sname) > 1:
                sname.pop()
                res.add(".".join(sname))
        return res
    blocknamesT = namedottree(blocknames)
    entrecs1, entrecs0 = [ ], [ ]
    for p, name, flags in nodes:
        if "ENTRANCE" in flags:
            entnames = dmp3d.nodepmap[p][0]
            sentnames = set.intersection(namedottree(entnames), blocknamesT)
            if sentnames:
                sentname = max(sentnames, key=lambda X: len(X))
                entrecs1.append((legnodesdict[p], name, sentname))
            else:
                entrecs0.append((legnodesdict[p], name, ""))
        
    entrecs1.sort(key=lambda X: X[2].split("."))
    entrecs0.sort(key=lambda X: X[1])
    entrecs = entrecs1 + entrecs0
    entrecblockstarts = [ ]
    return entrecs, entrecblockstarts


# geoid correction from wgs84 ellipsoid altitude to MSL
# ./geographiclib-get-geoids.sh minimal  (might have to move the files to /usr/local/share/GeographicLib
# https://geographiclib.sourceforge.io/html/geoid.html
def GetWGSGeoidcorrection(lng, lat):
    f = os.popen('GeoidEval --input-string "%f %f"' % (lat, lng))
    res = f.read().strip()
    print("Geoid made at", res)
    if res:
        return float(res)
    print("GeoidEval not installed or not working")
    if 49 <= lat <= 59 and -6 <= lng <= 2:
        return 48 # for yorkshire
    if 46 <= lat <= 48 and 9 <= lng <= 17:
        return 47 # for salzburg
    print("Geoideval can't be guessed outside of Austria or UK")
    return 0


def exportfortunnelvr(jsfile, dmp3d):
    entrancenodes = [node  for node in dmp3d.nodes  if "ENTRANCE" in node[2]]
    svxp0 = max((node[0]  for node in entrancenodes or dmp3d.nodes), key=(lambda X: (X[2], X[0], X[1])))
    svxp0 = P3(svxp0[0], svxp0[1], 0.0)
    csrec = { "svxp0":svxp0, "title":dmp3d.title, "headdate":dmp3d.headdate.isoformat() }
    if dmp3d.cs:
        print("We have a coordinate system (cs) ", dmp3d.cs)
        import pyproj
        proj = pyproj.Proj(dmp3d.cs)
        lngp0, latp0 = proj(svxp0[0], svxp0[1], inverse=True)
        lngp0, latp0
        ddeg = 0.01
        pxn, pyn = proj(lngp0, latp0+ddeg)
        nyfac, nxfac = (pyn-svxp0[1])/ddeg, (pxn-svxp0[0])/ddeg 
        pxe, pye = proj(lngp0+ddeg, latp0)
        eyfac, exfac = (pye-svxp0[1])/ddeg, (pxe-svxp0[0])/ddeg 
        csrec["svxp0"] = P3(lngp0, latp0, svxp0[2])
        csrec.update({ "cs":dmp3d.cs, "nyfac":nyfac, "nxfac":nxfac, "eyfac":eyfac, "exfac":exfac })

    leglines = [line  for line in dmp3d.lines  if line[0] != line[1] and "SURFACE" not in line[4]]
    xsects = [xsect  for xsect in dmp3d.xsects  if len(xsect) >= 2]

    # points as triples
    stationpoints = set()
    stationpoints.update(line[0]  for line in leglines)
    stationpoints.update(line[1]  for line in leglines)
    stationpoints = list(stationpoints)
    stationpoints.sort(key=lambda X: (X[2], X[0], X[1]))

    stationpointsdict = dict((p, i)  for i, p in enumerate(stationpoints))

    def convp(p):
        if "cs" in csrec:
            px, py = proj(p[0], p[1], inverse=True)
            p = P3(px, py, p[2])
            r = p - csrec["svxp0"]
            r = P3(csrec["nxfac"]*r[1] + csrec["exfac"]*r[0], csrec["nyfac"]*r[1] + csrec["eyfac"]*r[0], r[2])
        else:
            r = p - csrec["svxp0"]
        return r

    stationpointscoords = sum((tuple(convp(stationpoint))  for stationpoint in stationpoints), ())
    stationpointsnames = [ dmp3d.nodepmap[stationpoint][0][0] if stationpoint in dmp3d.nodepmap else ".%dy"%i \
                           for i, stationpoint in enumerate(stationpoints) ]
    legsconnections = sum(((stationpointsdict[legline[0]], stationpointsdict[legline[1]])  for legline in leglines), ())
    legsconnections = sum(((stationpointsdict[legline[0]], stationpointsdict[legline[1]])  for legline in leglines), ())
    legsstyles = [ legline[3]  for legline in leglines ]

    xsectgps = [ ]
    for xsectseq in xsects:
        xsectpoints, xsectindexes = [ ], [ ]
        for xs in xsectseq:
            xsp = dmp3d.nmapnodes[xs[0]]
            if xsp in stationpointsdict:  # avoid using a tube on a surface leg
                xsi = stationpointsdict[xsp]
                xsectpoints.append(xsp)
                xsectindexes.append(xsi)
        xsectrightvecs = [ ]
        for i in range(len(xsectpoints)):
            pback = convp(xsectpoints[max(0, i-1)])
            p = convp(xsectpoints[i])
            pfore = convp(xsectpoints[min(len(xsectpoints)-1, i+1)])
            vback = P3.ZNorm(P3(p.x - pback.x, p.y - pback.y, 0.0))
            vfore = P3.ZNorm(P3(pfore.x - p.x, pfore.y - p.y, 0.0))
            xsectplanevec = P3.ZNorm(vback + vfore)
            xsectrightvecs.append(xsectplanevec[1])
            xsectrightvecs.append(-xsectplanevec[0])
        xsectrightvecs
        xsectlruds = sum((xs[1]  for xs in xsectseq), ())
        xsectlruds
        xsectgps.append({ "xsectindexes":xsectindexes, "xsectrightvecs":xsectrightvecs, "xsectlruds":xsectlruds })
    xsectgps

    jrec = { "stationpointscoords": stationpointscoords,
             "stationpointsnames":  stationpointsnames, 
             "legsconnections":     legsconnections,
             "legsstyles":          legsstyles, 
             "xsectgps":            xsectgps
           }
    jrec.update(csrec)
    print(" ".join("%s:%d"%(k, len(v))  for k, v in jrec.items()  if type(v) in [tuple, list]))

    def round_floats(o):
        if isinstance(o, float):
            return round(o, 5)
        if isinstance(o, dict):
            return {k: round_floats(v) for k, v in o.items()}
        if isinstance(o, (list, tuple)):
            return [round_floats(x) for x in o]
        return o

    fout = open(jsfile, "w")
    json.dump(round_floats(jrec), fout)
    fout.close()
    

# main case with further libraries loaded and some command line help stuff
if __name__ == "__main__":
    from optparse import OptionParser
    parser = OptionParser()
    parser.add_option("-3", "--3d",         dest="s3d",        metavar="FILE",                    help="Input survex 3d file")
    parser.add_option("-d", "--dmp",        dest="dmp",        metavar="FILE",                    help="Input survex 3d dump file")
    parser.add_option("-x", "--svx",        dest="svx",        metavar="FILE",                    help="Input survex svx file")
    parser.add_option("-r", "--report",     dest="report",     default=False,action="store_true", help="Report stats")
    parser.add_option("-s", "--streamdump", dest="streamdmp",  default=False,action="store_true", help="Stream dmp from stdin")
    parser.add_option("-j", "--js",         dest="js",         metavar="FILE",                    help="Output js version 3d file")
    parser.add_option("-c", "--streamjs",   dest="streamjs",   default=False,action="store_true", help="Stream js to stdout")
    parser.add_option("-t", "--tunnelvr",   dest="tunnelvr",    default=False,action="store_true", help="TunnelVR format")
    parser.description = "Analyses or processes survex 3D file to do things with the passages\n(station beginning with 'fbmap_' should be mountaintops)"
    parser.epilog = "Best way to execute: dump3d yourcave.3d | ./parse3ddmp.py -s -r \n"

    # Code is here: https://bitbucket.org/goatchurch/survexprocessing
    options, args = parser.parse_args()
    
    # push command line args that look like files into file options 
    if len(args) >= 1 and re.search("\.js$", args[0]) and not options.js:
        options.js = args.pop(0)
    if len(args) >= 1 and re.search("\.dmp$", args[0]) and not options.dmp:
        options.dmp = args.pop(0)
    if len(args) >= 1 and re.search("\.3d$", args[0]) and not options.s3d:
        options.s3d = args.pop(0)
    if len(args) >= 1 and re.search("\.svx$", args[0]) and not options.svx:
        options.svx = args.pop(0)
    
    # get the input dmp stream
    if options.streamdmp:
        dstream = sys.stdin  # should timeout
    elif options.dmp:
        dstream = open(options.dmp)
    elif options.s3d:
        dstream = os.popen("%s -d %s" % (dump3dexe, options.s3d))
    elif options.svx:
        k = tempfile.NamedTemporaryFile(suffix=".3d")
        l = os.popen("cavern --output=%s %s" % (k.name, options.svx))
        print(l.read())
        dstream = os.popen("%s -d %s" % (dump3dexe, k.name))
    else:
        parser.print_help()
        exit(1)
        
    lines = dstream.readlines()
    if len(lines) <= 2:
        print("\n".join(lines))
        exit(1)
    dmp3d = DMP3d(lines)
    
    if options.report:
        dmp3d.printreport(options.dmp or options.s3d)
        if not options.js and not options.streamjs:
            exit(0)
            
    # json output from here onwards
    
    if options.tunnelvr:
        exportfortunnelvr(options.js, dmp3d)
        exit(0)

    if options.streamjs:
        fout = sys.stdout
    elif options.js:
        fout = open(options.js, "w")
    else:
        parser.print_help()
        exit(1)
        
    leglines = [line  for line in dmp3d.lines  if line[0] != line[1] and "SURFACE" not in line[4]]
    xsects = [xsect  for xsect in dmp3d.xsects  if len(xsect) >= 2]
    
    blocknames, legblockstarts, xsectblockstarts = allocatesortblocknames(leglines, xsects)
    assert len(blocknames) == len(legblockstarts)-1 == len(xsectblockstarts)-1
        
    fout.write('LoadSvx3d({"title":"%s", "date":"%s",\n' % (dmp3d.title, dmp3d.headdate))
    svxscale = 100;  # cms
    fout.write('    "scale": %f,\n' % svxscale)

    legnodes = set(p  for p, v in dmp3d.nodepmap.items()  if "ENTRANCE" in v[1])
    legnodes.update(line[0]  for line in leglines)
    legnodes.update(line[1]  for line in leglines)
    legnodes = list(legnodes)
    legnodes.sort(key=lambda X: (X[2], X[0], X[1]))
    legnodesdict = dict((p, i)  for i, p in enumerate(legnodes))

    # pick the mode everything will be relative to (ideally the highest entrance)
    try:
        svxp0 = max((node[0]  for node in dmp3d.nodes  if "ENTRANCE" in node[2]), key=(lambda X: (X[2], X[0], X[1])))
    except ValueError:  # max of empty list
        svxp0 = max(legnodes, key=lambda X: X[2])
    fout.write('    "p0": [%.0f,%.0f,%.0f],\n' % (svxp0[0]*svxscale, svxp0[1]*svxscale, svxp0[2]*svxscale))
    if dmp3d.cs:
        try:
            import pyproj
        except ImportError:
            print("Missing pyproj (the proj4) module")
            exit(1)
        proj = pyproj.Proj(dmp3d.cs)
        
        lngp0, latp0 = proj(svxp0[0], svxp0[1], inverse=True)
        fout.write('    "cs": "%s",\n' % (dmp3d.cs))
        fout.write('    "lngp0": %f, "latp0": %f, "altp0": %f, "geoidaltitude": %f,\n' % (lngp0, latp0, svxp0[2], GetWGSGeoidcorrection(lngp0, latp0)))

        #earthrad = 6378137; 
        #nyfac = 2*math.pi*earthrad/360; 
        #nxfac = 0; 
        #eyfac = 0; 
        #exfac = nyfac*math.cos(latp0*math.pi/180); 
        #print("gpsfacs", nyfac, nxfac, eyfac, exfac)

        ddeg = 0.01
        pxn, pyn = proj(lngp0, latp0+ddeg)
        nyfac, nxfac = (pyn-svxp0[1])/ddeg, (pxn-svxp0[0])/ddeg 
        pxe, pye = proj(lngp0+ddeg, latp0)
        eyfac, exfac = (pye-svxp0[1])/ddeg, (pxe-svxp0[0])/ddeg 
        #print("gpsfacs", nyfac, nxfac, eyfac, exfac)
        fout.write('    "nyfac": %f, "nxfac": %f, "eyfac": %f, "exfac": %f,\n' % (nyfac, nxfac, eyfac, exfac))

    fout.write('    "legnodes": [')
    for i, p in enumerate(legnodes):
        fout.write('%s%.0f,%.0f,%.0f' % ((i and "," or ""), (p[0]-svxp0[0])*svxscale, (p[1]-svxp0[1])*svxscale, (p[2]-svxp0[2])*svxscale))
    fout.write('],\n')
    
    fout.write('    "legindexes": [%s],\n' % ",".join("%d,%d" % (legnodesdict[p[0]], legnodesdict[p[1]])  for p in leglines))

    fout.write('    "blocknames": [%s],\n' % ",".join('"%s"' % blockname  for blockname in blocknames))
    fout.write('    "legblockstarts": [%s],\n' % ",".join('%d' % legblockstart  for legblockstart in legblockstarts))

    entrecs, entrecblockstarts = findallocateentrects(blocknames, legnodesdict, dmp3d.nodes)
    fout.write('    "legentrances": [%s],\n' % ",".join('%d,"%s","%s"' % entrec  for entrec in entrecs))
    
    fout.write('    "landmarks": [')
    landmarks = [node  for node in dmp3d.nodes  if re.search("(?:fbmap|landmark)_[^.]*$", node[1])]
    for i, node in enumerate(landmarks):
        landmarkname = node[1].split(".")[-1]
        landmarkname = landmarkname.split("_")
        if len(landmarkname) > 1:
            landmarkname = landmarkname[1:]
        landmarkname = " ".join(lm.capitalize()  for lm in landmarkname)
        p = node[0]
        fout.write('%s["%s",%.0f,%.0f,%.0f]' % ((i and "," or ""), landmarkname, (p[0]-svxp0[0])*svxscale, (p[1]-svxp0[1])*svxscale, (p[2]-svxp0[2])*svxscale))
    fout.write('],\n')
    
    if xsects:
        passagequads = [ ]
        passagexcs = [ ] # [ [ (q0,q1,q1,q2), ... ], [ ... ], ... ]
        for xsect in xsects:
            assert len(xsect) >= 2
            quads, xcs = dmp3d.GetXSectionQuadHedronP(xsect)
            passagequads.extend(quads)
            passagexcs.append(xcs)

        cumupassagexcsseq = [ ]
        fout.write('    "passagexcs": [')
        for i, xcs in enumerate(passagexcs):
            cumupassagexcsseq.append((cumupassagexcsseq and cumupassagexcsseq[-1] or 0)+len(xcs))
            for j, q in enumerate(xcs):
                for k, p in enumerate(q):
                    fout.write('%s%.0f,%.0f,%.0f' % (((i or j or k) and "," or ""), (p[0]-svxp0[0])*svxscale, (p[1]-svxp0[1])*svxscale, (p[2]-svxp0[2])*svxscale))
        fout.write('],\n')
        
        fout.write('    "cumupassagexcsseq": [%s],\n' % ",".join("%d" % cv  for cv in cumupassagexcsseq))
        fout.write('    "xsectblockstarts": [%s],\n' % ",".join('%d' % xsectblockstart  for xsectblockstart in xsectblockstarts))
    
    fout.write('    "dummy":0\n')
    fout.write('});\n')

    """twistcodewiki running:
    import os, sys
    sys.path.append("/home/goatchurch/caving/survexprocessing/")
    from parse3ddmp import DMP3d
    dname = "/home/goatchurch/caving/survexprocessing/Skydusky.3d"
    dstream = os.popen("dump3d -d %s" % dname)
    dmp3d = DMP3d(dstream)
    """
