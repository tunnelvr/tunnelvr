from parse3ddmp import DMP3d
import os, sys, re


dump3dexe = '"C:\\Program Files (x86)\\Survex\\dump3d.exe"'
if sys.platform == "linux":
    dump3dexe = 'dump3d'

from optparse import OptionParser
parser = OptionParser()
parser.add_option("-3", "--3d",         dest="s3d",        metavar="FILE",                    help="Input survex 3d file")
parser.add_option("-j", "--js",         dest="js",         metavar="FILE",                    help="Output json version 3d file")
parser.add_option("-a", "--align",      dest="alignjs",    metavar="FILE",                    help="json file to align with")
parser.description = "Convert survex 3D file to do json format for tunnelvr"
parser.epilog = "python convertdmptojson.py survexfile \n"

options, args = parser.parse_args()

# push command line args that look like files into file options 
if len(args) >= 1 and re.search("\.3d$", args[0]) and not options.s3d:
    options.s3d = args.pop(0)
if len(args) >= 1 and re.search("\.json$", args[0]) and not options.js:
    options.js = args.pop(0)
if not options.js:
    if not options.s3d:
        parser.print_help()
        exit(1)
    options.js = os.path.splitext(options.s3d)[0]+".json"

    
#fname = "Ireby/Ireby2/Ireby2.3d"
#outputfile = "Ireby/Ireby2/Ireby2.json"
#fname = "LoneOak.3d"
print("Reading: ", options.s3d, "  writing: ", options.js)

dstream = os.popen("%s -d %s" % (dump3dexe, options.s3d))
lines = dstream.readlines()
dmp3d = DMP3d(lines)

from parse3ddmp import P3
import json

leglines = [line  for line in dmp3d.lines  if line[0] != line[1] and "SURFACE" not in line[4]]
xsects = [xsect  for xsect in dmp3d.xsects  if len(xsect) >= 2]

if dmp3d.cs:
    print("*cs", dmp3d.cs)
    if "+init=epsg:27700" in dmp3d.cs:
        print("OSGB coordinate frame found, so is rectilinear")
    else:
        print("unknown coordinate frame")
        exit(1)

# points as triples
stationpoints = set()
stationpoints.update(line[0]  for line in leglines)
stationpoints.update(line[1]  for line in leglines)

# unexplained missing cases
for xsectseq in xsects:
    xsectpoints = [dmp3d.nmapnodes[xs[0]]  for xs in xsectseq]
    for xsectpoint in xsectpoints:
        if xsectpoint not in stationpoints:
            print("xsectpoint missing ", xsectpoint)
            stationpoints.add(xsectpoint)

stationpoints = list(stationpoints)
stationpoints.sort(key=lambda X: (X[2], X[0], X[1]))

# centralize the sketch
def rangerat(ps, i, maxfac):
    return (1-maxfac)*min(p[i]  for p in ps) + maxfac*max(p[i]  for p in ps)
svxp0 = P3(rangerat(stationpoints, 0, 0.5), rangerat(stationpoints, 1, 0.5), rangerat(stationpoints, 2, 1.0))

if options.alignjs:
    jrecprev = json.loads(open(options.alignjs, "r").read())
    astationpointmap = { }
    aspc = jrecprev["stationpointscoords"]
    stationvecs = [ ]
    stationdisplacementvectors = [ ]
    for i, astationpointname in enumerate(jrecprev["stationpointsnames"]):
        if astationpointname:
            astationpointname = "skirwith-cave.skirwith_jgtslapdash."+astationpointname
            currstationpointpos = dmp3d.nmapnodes.get(astationpointname)
            if currstationpointpos != None:
                loadedstationpointpos = P3(aspc[i*3], aspc[i*3+1], aspc[i*3+2])
                print(astationpointname, currstationpointpos - loadedstationpointpos)
                stationdisplacementvectors.append(currstationpointpos - loadedstationpointpos)
                astationpointmap[astationpointname] = P3(aspc[i*3], aspc[i*3+1], aspc[i*3+2])
    if stationdisplacementvectors:
        avgdisplacement = sum(stationdisplacementvectors, P3(0,0,0))*(1/len(stationdisplacementvectors))
        print("setting origin from ", svxp0, "to", avgdisplacement)
        svxp0 = avgdisplacement
        
stationpointsdict = dict((p, i)  for i, p in enumerate(stationpoints))
stationpointscoords = sum((tuple(stationpoint - svxp0)  for stationpoint in stationpoints), ())
stationpointsnames = [ dmp3d.nodepmap[stationpoint][0][0]  for stationpoint in stationpoints ]
legsconnections = sum(((stationpointsdict[legline[0]], stationpointsdict[legline[1]])  for legline in leglines), ())
legsconnections = sum(((stationpointsdict[legline[0]], stationpointsdict[legline[1]])  for legline in leglines), ())
legsstyles = [ legline[3]  for legline in leglines ]

    

xsectgps = [ ]
for xsectseq in xsects:
    xsectpoints = [dmp3d.nmapnodes[xs[0]]  for xs in xsectseq]
    xsectindexes = [ stationpointsdict[xsectpoint]  for xsectpoint in xsectpoints ]
    xsectrightvecs = [ ]
    for i in range(len(xsectpoints)):
        pback = xsectpoints[max(0, i-1)]
        p = xsectpoints[i]
        pfore = xsectpoints[min(len(xsectpoints)-1, i+1)]
        vback = P3.ZNorm(P3(p.x - pback.x, p.y - pback.y, 0.0))
        vfore = P3.ZNorm(P3(pfore.x - p.x, pfore.y - p.y, 0.0))
        xsectplanevec = P3.ZNorm(vback + vfore)
        xsectrightvecs.append(xsectplanevec[1])
        xsectrightvecs.append(-xsectplanevec[0])
    xsectrightvecs
    xsectlruds = sum((xs[1]  for xs in xsectseq), ())
    xsectlruds
    xsectgps.append({ "xsectindexes":xsectindexes, "xsectrightvecs":xsectrightvecs, "xsectlruds":xsectlruds })

jrec = { "stationpointscoords": stationpointscoords,
         "stationpointsnames":  stationpointsnames, 
         "legsconnections":     legsconnections,
         "legsstyles":          legsstyles, 
         "xsectgps":            xsectgps
       }

open(options.js, "w").write(json.dumps(jrec))


print("Array sizes:", " ".join("%s:%d"%(k, len(v))  for k, v in jrec.items()))
open(options.js, "w").write(json.dumps(jrec))


