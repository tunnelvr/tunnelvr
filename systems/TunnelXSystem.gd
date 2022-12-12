extends Spatial

onready var sketchsystem = get_node("/root/Spatial/SketchSystem")

var tunnelx_xcname = null
var tunnelx_tubename = null
var tunnelxlocoffset = Vector3()
var tunnelxlocoffset_local = Vector3()
const tunnelxFac = 0.1
var tunnelxZshift = 10.0
var tunnelxZscaledown = 0.2

# things to do: 
# 
# implement nodeconnzsetrelative
# the areas are going to need sensible triangulating, 
#   some kind of nice grid that works on other faces
# sketchgraphicspanel.GUpdateSymbolLayout();
# convert the skframes into floor sketches below the connective bits
# is fixing up and exporting remotely feasible?
# use xcsectormaterials to set the linestyle!
# 

class sd0class:
	static func sd0(a, b):
		return a[0] < b[0]

func maketunnelxnetwork(nodepoints, onepathpairs, xctunnelxtube, bdropangles):
	var Lpathvectorseq = { } 
	for i in nodepoints.keys():
		Lpathvectorseq[i] = [ ]  # [ (arg, pathindex*2 + (0 if bfore else 1)) ]

	var xcdrawinglink = xctunnelxtube.xcdrawinglink
	var xclinkintermediatenodes = xctunnelxtube.xclinkintermediatenodes
	var Ndrawinglinks = len(xcdrawinglink)/2
	for i in range(Ndrawinglinks):
		var i0 = xcdrawinglink[i*2]
		var i1 = xcdrawinglink[i*2+1]
		var p0 = nodepoints[i0]
		var p1 = nodepoints[i1]
		var p0i = p1
		var p1i = p0
		if xclinkintermediatenodes != null and xclinkintermediatenodes[i] != null and len(xclinkintermediatenodes[i]) != 0:
			p0i = xctunnelxtube.intermedpointpos(p0, p1, xclinkintermediatenodes[i][0])
			p1i = xctunnelxtube.intermedpointpos(p0, p1, xclinkintermediatenodes[i][-1])

		var vec30 = p0i - p0
		var vec0 = Vector2(vec30.x, vec30.y)
		var vec31 = p1 - p1i
		var vec1 = Vector2(vec31.x, vec31.y)
		Lpathvectorseq[i0].push_back([vec0.angle(), i*2])
		Lpathvectorseq[i1].push_back([(-vec1).angle(), i*2+1])

	if onepathpairs != null:
		var Npaths = len(onepathpairs)/2
		for i in range(Npaths):
			var i0 = onepathpairs[i*2]
			var i1 = onepathpairs[i*2+1]
			var vec3 = nodepoints[i1] - nodepoints[i0]
			var vec = Vector2(vec3.x, vec3.y)
			Lpathvectorseq[i0].push_back([vec.angle(), Ndrawinglinks*2 + i*2])
			Lpathvectorseq[i1].push_back([(-vec).angle(), Ndrawinglinks*2 + i*2+1])


	if bdropangles:
		var res = { }
		for i in nodepoints.keys():
			var pathvectorseq = Lpathvectorseq[i]
			pathvectorseq.sort_custom(sd0class, "sd0")
			var pathvectorseqI = [ ]
			for jp in pathvectorseq:
				pathvectorseqI.push_back(jp[1])
			res[i] = pathvectorseqI
		return res
		
	for pathvectorseq in Lpathvectorseq.values():
		pathvectorseq.sort_custom(sd0class, "sd0")
	return Lpathvectorseq



func ShortestPathsToCentrelineNodes(Sopn, num, nodepoints, onepathpairs, Lpathvectorseq):
	var proxqueue = [ [ 0.0, Sopn, 0.0 ] ]  # [ (dist, opn, zdist) ]
	var opnvisited = { }
	var closestcentrelinenodes = [ ]
	while len(proxqueue) != 0:
		var iqmin = 0
		for i in range(iqmin):
			if proxqueue[i][0] < proxqueue[iqmin][0]:
				iqmin = i
		var qmin = proxqueue[iqmin]
		proxqueue[iqmin] = proxqueue[-1]
		proxqueue.pop_back()
		var opn = qmin[1]
		if opn in opnvisited:
			continue
		opnvisited[opn] = 1
		if not opn.begins_with("_"):
			closestcentrelinenodes.append(qmin)
			if len(closestcentrelinenodes) == num:
				break
			continue
		for piv in Lpathvectorseq[opn]:
			assert (onepathpairs[piv[1]] == opn)
			var pivother = piv[1] + (1 if (piv[1] % 2) == 0 else -1)
			var opnother = onepathpairs[pivother]
			if opnother in opnvisited:
				continue
			var pathlen = Vector2(nodepoints[opn].x - nodepoints[opnother].x, nodepoints[opn].y - nodepoints[opnother].y).length()
			var nodeconnzsetrelative = 0.0
			proxqueue.push_back([qmin[0] + pathlen, opnother, qmin[2] + nodeconnzsetrelative])
	return closestcentrelinenodes
	

func updateznodes(xctunnelxdrawing, xctunnelxtube, bflatteninzfor2Dviewing=false):
	var nodepoints = xctunnelxdrawing.nodepoints
	var Lpathvectorseq = maketunnelxnetwork(nodepoints, null, xctunnelxtube, false)
	var nextnodepoints = { }
	for opn in nodepoints:
		if not opn.begins_with("_"):
			continue
		var ccons = ShortestPathsToCentrelineNodes(opn, 4, xctunnelxdrawing.nodepoints, xctunnelxtube.xcdrawinglink, Lpathvectorseq)
		if len(ccons) == 0: 
			continue

		var tweight = 0.0
		var zaltsum = 0.0
		for ccon in ccons:
			if ccon[0] != 0.0:
				var weight = 1.0/(ccon[0]*ccon[0])
				zaltsum += (nodepoints[ccon[1]].z + ccon[2]) * weight;
				tweight += weight;
			else:
				tweight = 1.0
				zaltsum = nodepoints[ccon[1]].z + ccon[2]
				break
		if tweight != 0.0:
			var newz = zaltsum/tweight
			nextnodepoints[opn] = Vector3(nodepoints[opn].x, nodepoints[opn].y, newz)

	if bflatteninzfor2Dviewing:
		for opn in nodepoints:
			var pt = nextnodepoints[opn] if nextnodepoints.has(opn) else nodepoints[opn]
			pt.z = tunnelxZshift + (pt.z - tunnelxZshift)*tunnelxZscaledown
			nextnodepoints[opn] = pt
			
	var prevnodepoints = { }
	for opn in nextnodepoints:
		prevnodepoints[opn] = nodepoints[opn]

	return ({ "name":xctunnelxdrawing.name, 
			  "prevnodepoints":prevnodepoints,
			  "nextnodepoints":nextnodepoints }) 



class SkFrame:
	var sfscaledown : float
	var sfrotatedeg : float
	var sfelevrotdeg : float
	var sfelevvertplane : String
	var sftrans : Vector2
	var sfsketch : String
	var sfstyle : String
	var nodeconnzsetrelative : float
	var sfpixwidthheight : Vector2

class SkPath:
	var from : int
	var to : int
	var linestyle : String
	var pts : PoolVector3Array
	var subsets : PoolStringArray
	var cltail : String
	var clhead : String
	var pctext_style : String
	var pctext_rel : Vector2
	var pctext : String
	var area_signal : String
	var skframe : SkFrame	

func skpath(xp):
	var sk = SkPath.new()
	sk.from = int(xp.get_named_attribute_value("from"))
	sk.to = int(xp.get_named_attribute_value("to"))
	sk.linestyle = xp.get_named_attribute_value("linestyle")

	var pts = [ ]
	var subsets = [ ]
	while not (xp.get_node_type() == xp.NODE_ELEMENT_END and xp.get_node_name() == "skpath"):
		if xp.get_node_type() == xp.NODE_ELEMENT:
			if xp.get_node_name() == "pt":
				var pt = Vector3(float(xp.get_named_attribute_value("X"))*tunnelxFac, -float(xp.get_named_attribute_value("Y"))*tunnelxFac, tunnelxZshift)
				if sk.linestyle == "centreline":
					pt.z = float(xp.get_named_attribute_value("Z"))*tunnelxFac + tunnelxZshift
				pts.append(pt)
			elif xp.get_node_name() == "sketchsubset":
				subsets.append(xp.get_named_attribute_value("subname"))
			elif xp.get_node_name() == "cl_stations":
				sk.cltail = xp.get_named_attribute_value("tail")
				sk.clhead = xp.get_named_attribute_value("head")
			elif xp.get_node_name() == "pcarea":
				sk.area_signal = xp.get_named_attribute_value("area_signal")
				if sk.area_signal == "frame":
					var sf = SkFrame.new()
					sf.sfscaledown = float(xp.get_named_attribute_value("sfscaledown"))
					sf.sfrotatedeg = float(xp.get_named_attribute_value("sfrotatedeg"))
					sf.sfelevrotdeg = float(xp.get_named_attribute_value("sfelevrotdeg"))
					sf.sfelevvertplane = xp.get_named_attribute_value("sfelevvertplane")
					sf.sftrans = Vector2(float(xp.get_named_attribute_value("sfxtrans")), float(xp.get_named_attribute_value("sfytrans")))
					sf.sfsketch = xp.get_named_attribute_value("sfsketch")
					sf.sfstyle = xp.get_named_attribute_value("sfstyle")
					sf.nodeconnzsetrelative = float(xp.get_named_attribute_value("nodeconnzsetrelative"))
					sf.sfpixwidthheight = Vector2(float(xp.get_named_attribute_value("sfpixwidth")), float(xp.get_named_attribute_value("sfpixheight")))
					sk.skframe = sf
					print(sf.sfsketch)
			
			elif xp.get_node_name() == "pctext":
				if xp.get_named_attribute_value("style") != "":
					sk.pctext_style = xp.get_named_attribute_value("style")
					sk.pctext_rel = Vector2(float(xp.get_named_attribute_value("nodeposxrel")), float(xp.get_named_attribute_value("nodeposyrel")))
					xp.read()
					sk.pctext = xp.get_node_data() if xp.get_node_type() == xp.NODE_TEXT else ""
					#print("TEXT ", sk.pctext_style, " ", sk.pctext if len(sk.pctext) < 20 else len(sk.pctext))
		xp.read()
	sk.pts = PoolVector3Array(pts)
	if subsets:
		sk.subsets = PoolStringArray(subsets)
	return sk
	
	
func skpathstoaabb(skpaths):
	var xlo = 0.0
	var xhi = 0.0
	var ylo = 0.0
	var yhi = 0.0
	var zlo = 0.0
	var zhi = 0.0
	var bfirstxy = true
	var bfirstz = true
	for sk in skpaths:
		for pt in sk.pts:
			if pt.x < xlo or bfirstxy:
				xlo = pt.x
			if pt.x > xhi or bfirstxy:
				xhi = pt.x
			if pt.y < ylo or bfirstxy:
				ylo = pt.y
			if pt.x > xhi or bfirstxy:
				yhi = pt.y
			bfirstxy = false
		if sk.linestyle == "centreline":
			for pt in sk.pts:
				if pt.z < zlo or bfirstz:
					zlo = pt.z
				if pt.z > zhi or bfirstz:
					zhi = pt.z
				bfirstz = false
	return AABB(Vector3(xlo, ylo, zlo), Vector3(xhi-xlo, yhi-ylo, zhi-zlo))


func makenodeidsmap(skpaths):
	var nodeidsmap = { }
	for sk in skpaths:
		if sk.linestyle == "centreline":
			nodeidsmap[sk.from] = sk.cltail.replace(".", ",")
			nodeidsmap[sk.to] = sk.clhead.replace(".", ",")
	for sk in skpaths:
		if not (sk.from in nodeidsmap):
			nodeidsmap[sk.from] = "_%d" % sk.from
		if not (sk.to in nodeidsmap):
			nodeidsmap[sk.to] = "_%d" % sk.to
	return nodeidsmap
	

func makexcdata(skpaths, nodeidsmap, ptoffset):
	var nodepoints = { }
	var conepathpairs = [ ]
	for sk in skpaths:
		if not nodepoints.has(nodeidsmap[sk.from]) or sk.linestyle == "centreline":
			nodepoints[nodeidsmap[sk.from]] = sk.pts[0] + ptoffset
		if not nodepoints.has(nodeidsmap[sk.to]) or sk.linestyle == "centreline":
			nodepoints[nodeidsmap[sk.to]] = sk.pts[-1] + ptoffset

	var rotzminus90 = Basis(Vector3(1,0,0), Vector3(0,0,-1), Vector3(0,1,0))
	var bbcenvec = Vector3()
	var centrelinetransformpos = Transform(rotzminus90, -rotzminus90.xform(bbcenvec))
	var xcdata = { "name":sketchsystem.uniqueXCname("tunnelx"), 
				   "drawingtype":DRAWING_TYPE.DT_CENTRELINE,
				   "drawingvisiblecode":DRAWING_TYPE.VIZ_XCD_PLANE_AND_NODES_VISIBLE,
				   "transformpos":centrelinetransformpos, 
				   "nodepoints":nodepoints, 
				   "onepathpairs":conepathpairs
				 }
	return xcdata


func makedrawinglinks(skpaths, nodeidsmap, spbasis):
	var drawinglinks = [ ]
	for sk in skpaths:
		drawinglinks.push_back(nodeidsmap[sk.from])
		drawinglinks.push_back(nodeidsmap[sk.to])
		drawinglinks.push_back(sk.linestyle)
		if len(sk.pts) > 2:
			var intermediatepoints = [ ]
			var p0 = sk.pts[0]
			var p1 = sk.pts[-1]
			var vec = p1 - p0
			var vecsq = vec.length_squared()
			if vecsq == 0.0:
				vecsq = 1.0
			for i in range(1, len(sk.pts) - 1):
				var dpz = clamp((sk.pts[i] - p0).dot(vec)/vecsq, 0.0, 1.0)
				var sp = lerp(p0, p1, dpz)
				var dp = sk.pts[i] - sp
				intermediatepoints.push_back(Vector3(dp.dot(spbasis.x), dp.dot(spbasis.z), dpz))
			drawinglinks.push_back(intermediatepoints)
		else:
			drawinglinks.push_back(null)
	return drawinglinks

func makedrawinglinksDL(skpaths, nodeidsmap, spbasis, xcdrawinglink, xcsectormaterials, xclinkintermediatenodes):
	var drawinglinks = [ ]
	for sk in skpaths:
		xcdrawinglink.push_back(nodeidsmap[sk.from])
		xcdrawinglink.push_back(nodeidsmap[sk.to])
		xcsectormaterials.push_back(sk.linestyle)
		if len(sk.pts) > 2:
			var intermediatepoints = [ ]
			var p0 = sk.pts[0]
			var p1 = sk.pts[-1]
			var vec = p1 - p0
			var vecsq = vec.length_squared()
			if vecsq == 0.0:
				vecsq = 1.0
			for i in range(1, len(sk.pts) - 1):
				var dpz = clamp((sk.pts[i] - p0).dot(vec)/vecsq, 0.0, 1.0)
				var sp = lerp(p0, p1, dpz)
				var dp = sk.pts[i] - sp
				intermediatepoints.push_back(Vector3(dp.dot(spbasis.x), dp.dot(spbasis.z), dpz))
			xclinkintermediatenodes.push_back(intermediatepoints)
		else:
			xclinkintermediatenodes.push_back([])
	return drawinglinks

	

var linestyleboundaries = [ "wall", "estwall", "detail", "pitchbound", "ceilingbound", "invisible" ]

func SArealinkssequence(idl, Lpathvectorseq, xcdrawinglink, linestyles):
	var seq = [ ]
	var innerconnectives = [ ]
	while (len(seq) == 0 or seq[0] != idl) and (len(seq) < 10000):
		seq.push_back(idl)
		var idlo = idl + (1 if ((idl%2) == 0) else -1)
		var opn = xcdrawinglink[idlo]
		var Npathvectorseq = Lpathvectorseq[opn]
		var j = Npathvectorseq.find(idlo)
		assert (j != -1)
		var idloB = idlo
		for k in range(1, len(Npathvectorseq)):
			var idloL = Npathvectorseq[((j + k) % len(Npathvectorseq))]
			var linestyleL = linestyles[int(idloL/2)]
			if linestyleboundaries.has(linestyleL):
				idloB = idloL
				break
			elif linestyleL == "connective":
				innerconnectives.push_back(idloL)
		idl = idloB
	return seq

# make the polygon
# check its orientation
# do the rough and crappy triangulation
# (make an improved smooth triangulation if we can)
# extract the contour colours
# extract the subsets
# colour the triangulation
# check with big big tunnelx file
# check we are importing the centreline properly
# implement the dropdown stuff


#func Sareapolygon(dlseq, nodepoints, xcdrawinglink, xclinkintermediatenodes):
#	var res = [ ]
#	for idl in dlseq:
#		var i = int(idl/2)
#		var bfore = ((idl%2) == 0)
#		var idlo = idl + (1 if bfore else -1)
#		var intermediatenodes = xclinkintermediatenodes[idlo]

#		res.push_back()

func SAreacontour(dlseq, xctunnelxdrawing, xctunnelxtube):
	var areacontour = [ ]
	var nodepoints = xctunnelxdrawing.nodepoints
	var xcdrawinglink = xctunnelxtube.xcdrawinglink
	var xclinkintermediatenodes = xctunnelxtube.xclinkintermediatenodes
	assert ((xctunnelxtube.xcname0 == xctunnelxtube.xcname1) and (xctunnelxdrawing.get_name() == xctunnelxtube.xcname0))
	for idl in dlseq:
		var i = int(idl/2)
		var p0 = xctunnelxdrawing.transform * xctunnelxdrawing.nodepoints[xcdrawinglink[i*2]]
		var p1 = xctunnelxdrawing.transform * xctunnelxdrawing.nodepoints[xcdrawinglink[i*2+1]]
		var intermediatenodes = ([ ] if xclinkintermediatenodes == null else xclinkintermediatenodes[i])
		if (idl%2) == 0:
			areacontour.push_back(p0)
		else:
			areacontour.push_back(p1)
			intermediatenodes = intermediatenodes.duplicate()
			intermediatenodes.invert()
		for dp in intermediatenodes:
			var p1mtrans = xctunnelxtube.intermedpointposT(p0, p1, dp)
			areacontour.push_back(p1mtrans.origin)
	return areacontour


func UpdateSAreas(xctunnelxdrawing, xctunnelxtube):
	var nodepoints = xctunnelxdrawing.nodepoints
	var xclinkintermediatenodes = xctunnelxtube.xclinkintermediatenodes
	var Lpathvectorseq = maketunnelxnetwork(nodepoints, null, xctunnelxtube, true)
	var xcdrawinglink = xctunnelxtube.xcdrawinglink
	var linestyles = xctunnelxtube.xcsectormaterials
	var Ndrawinglinks = len(xcdrawinglink)/2
	var drawinglinksvisited = { }
	var surfaceTools = [ ]
	for idl in range(Ndrawinglinks*2):
		var i = int(idl/2)
		if (not (linestyles[i] in linestyleboundaries)) or drawinglinksvisited.has(idl):
			continue
		var dlseq = SArealinkssequence(idl, Lpathvectorseq, xcdrawinglink, linestyles)
		for ldil in dlseq:
			assert (not drawinglinksvisited.has(ldil))
			drawinglinksvisited[ldil] = 1
		var areacontour = SAreacontour(dlseq, xctunnelxdrawing, xctunnelxtube)
		var rotzminus90 = Basis(Vector3(1,0,0), Vector3(0,0,-1), Vector3(0,1,0))
		var arr = makegoodtriangulation(areacontour, rotzminus90)
		if arr and arr[Mesh.ARRAY_INDEX]:
			var surfaceTool = SurfaceTool.new()
			surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
			for u in arr[Mesh.ARRAY_INDEX]:
				surfaceTool.add_uv(arr[Mesh.ARRAY_TEX_UV][u])
				surfaceTool.add_vertex(arr[Mesh.ARRAY_VERTEX][u])
			surfaceTools.append(surfaceTool)		

	return surfaceTools


func loadtunnelxsketch(fname):
	var xp = XMLParser.new()
	xp.open(fname)
	for i in range(3):
		xp.read()
		if xp.get_node_type() == xp.NODE_ELEMENT:
			break
		print("xml1 ", xp.get_node_type())
	if not (xp.get_node_type() == xp.NODE_ELEMENT and xp.get_node_name() == "tunnelxml"):
		print("bailing out ", xp.get_node_type())
		print(xp.get_node_name())
		return
	xp.read()
	if not (xp.get_node_type() == xp.NODE_ELEMENT and xp.get_node_name() == "sketch"):
		print("bailing out ", xp.get_node_type())
		print(xp.get_node_name())
		return
	tunnelxlocoffset = Vector3(float(xp.get_named_attribute_value("locoffsetx")), float(xp.get_named_attribute_value("locoffsety")), float(xp.get_named_attribute_value("locoffsetz")))
		
	var skpaths = [ ]
	for i in range(10000):
		xp.read()
		if xp.get_node_type() == xp.NODE_ELEMENT_END and xp.get_node_name() == "sketch":
			print("done ", i)
			break
		if xp.get_node_type() == xp.NODE_ELEMENT and xp.get_node_name() == "skpath":
			var sk = skpath(xp)
			skpaths.append(sk)

	var skpathsaabb = skpathstoaabb(skpaths)
	print("Num_skpaths ", len(skpaths), " aabb: ", skpathsaabb)
	tunnelxlocoffset_local = skpathsaabb.get_center()

	var nodeidsmap = makenodeidsmap(skpaths)
	var xcdata = makexcdata(skpaths, nodeidsmap, -tunnelxlocoffset_local)

	var xcdrawinglink = [ ]
	var xcsectormaterials = [ ]
	var xclinkintermediatenodes = [ ]
	var newdrawinglinks = makedrawinglinksDL(skpaths, nodeidsmap, xcdata["transformpos"].basis, xcdrawinglink, xcsectormaterials, xclinkintermediatenodes)
	var xctdata = { "tubename":"**notset", 
					"xcname0":xcdata["name"],
					"xcname1":xcdata["name"],
					"xcdrawinglink":xcdrawinglink, 
					"xcsectormaterials":xcsectormaterials, 
					"xclinkintermediatenodes":xclinkintermediatenodes
				  }
	sketchsystem.setnewtubename(xctdata)
	tunnelx_xcname = xcdata["name"]
	tunnelx_tubename = xctdata["tubename"]
	sketchsystem.actsketchchange([ xcdata, xctdata ])

	var xctunnelxdrawing = sketchsystem.get_node("XCdrawings").get_node(tunnelx_xcname)
	var xctunnelxtube = sketchsystem.get_node("XCtubes").get_node(tunnelx_tubename)
	var xczdata = updateznodes(xctunnelxdrawing, xctunnelxtube, true)
	var xctupdate = { "xcvizstates":{ xctunnelxdrawing.get_name():DRAWING_TYPE.VIZ_XCD_NODES_VISIBLE }, 
					  "updatetubeshells":[{"tubename":xctunnelxtube.get_name(), "xcname0":xctunnelxtube.xcname0, "xcname1":xctunnelxtube.xcname0 }] }
	#sketchsystem.actsketchchange([ xczdata ])
	sketchsystem.actsketchchange([ xczdata, xctupdate ])
	

var basicbadtriangulation = true
var goodpolyslicewidth = 0.5

func makebadtriangulation(contour, flataligntransform):
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	var rpolygon = [ ]
	for p in contour:
		var tp = flataligntransform.xform(p)
		rpolygon.push_back(Vector2(tp.x, tp.y))
	var polygon = PoolVector2Array(rpolygon)
	if Geometry.is_polygon_clockwise(polygon):
		return [ ]
	var pi = Geometry.triangulate_polygon(rpolygon)
	arr[Mesh.ARRAY_VERTEX] = PoolVector3Array(contour)
	var uvs = [ ]
	for p in contour:
		uvs.push_back(Vector2(p.x, p.z))
	arr[Mesh.ARRAY_TEX_UV] = PoolVector2Array(uvs)
	arr[Mesh.ARRAY_INDEX] = PoolIntArray(pi)
	return arr

class SslypolygonX:
	var slypolygon
	func sly(i, j):
		return slypolygon[i].x < slypolygon[j].x


func makegoodtriangulation(contour, flataligntransform):
	if basicbadtriangulation:
		return makebadtriangulation(contour, flataligntransform)
	
	var rcontour = [ ]
	var ylo = flataligntransform.xform(contour[0]).y
	var yhi = ylo
	for cp in contour:
		var p = flataligntransform.xform(cp)
		rcontour.push_back(p)
		ylo = min(ylo, p.y)
		yhi = max(yhi, p.y)

	var nslices = int((yhi - ylo)/goodpolyslicewidth + 1.1)
	var sliceyvals = [ ]
	var slyindexpts = [ ]
	for i in range(1, nslices):
		sliceyvals.push_back(lerp(ylo, yhi, i*1.0/nslices))
		slyindexpts.push_back([])
		
	var p0 = rcontour[-1]
	var islice = 0
	while islice < len(sliceyvals) and sliceyvals[islice] < p0.y:
		islice += 1

	var slypolygon = [ ]
	var slyslice = [ ]
	for p in rcontour:
		assert (islice == len(sliceyvals) or p0.y <= sliceyvals[islice])
		assert (islice == 0 or p0.y > sliceyvals[islice-1])
		if p.y > p0.y:
			while islice < len(sliceyvals) and sliceyvals[islice] < p.y:
				var lam = inverse_lerp(p0.y, p.y, sliceyvals[islice])
				slypolygon.push_back(Vector3(lerp(p0.x, p.x, lam), sliceyvals[islice], lerp(p0.z, p.z, lam)))
				slyindexpts[islice].push_back(len(slypolygon))
				islice += 1
				slyslice.push_back(islice)
		else:
			while islice >= 1 and sliceyvals[islice-1] >= p.y:
				islice -= 1
				var lam = inverse_lerp(p0.y, p.y, sliceyvals[islice])
				slypolygon.push_back(Vector3(lerp(p0.x, p.x, lam), sliceyvals[islice], lerp(p0.z, p.z, lam)))
				slyindexpts[islice].push_back(len(slypolygon))
				slyslice.push_back(islice)
		slypolygon.push_back(p)
		slyslice.push_back(islice)
		p0 = p

	var SyX = SslypolygonX.new()
	SyX.slypolygon = slypolygon
	for slyindexptsL in slyindexpts:
		slyindexptsL.sort_custom(SyX, "sly")

	var slabs = [ ]
	for Jislice in range(len(slyindexpts)):
		break
		for j in slyindexpts[Jislice]:
			if slyindexpts[Jislice][j] == -1:
				continue
			var slabi = [ ]
			var i = slyindexpts[Jislice][j]
			islice = slyslice[i]
#			assert (islice == Jislice or islice == Jslice+1)
#			while 
			

			slabs.push_back(slabi)
			
			
	print("ss ", len(slypolygon), " ", len(rcontour))
	return makebadtriangulation(contour, flataligntransform)

