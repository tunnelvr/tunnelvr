extends Spatial

onready var sketchsystem = get_node("/root/Spatial/SketchSystem")

var tunnelx_xcname = null
var tunnelx_tubename = null
var tunnelxlocoffset = Vector3()
var tunnelxlocoffset_local = Vector3()
const tunnelxFac = 0.1
var tunnelxZbottom = 3.0
var tunnelxZshift = 13.0
var tunnelxZscaledown = 1.0  # 0.5
var basicbadtriangulation = false
var goodpolyslicewidth = 0.5
var floordownfromcentrelineoffset = 0.8

# things to do: 
# 
# labels coming up as those flagsigns
# no setting of materials or other edits in UI when it's the tunnelx type
# connecting in from other headset should apply the fill areas
# check problem areas in top canyons in the tunnelx file


# We could separate the centreline thing into its own xcdrawing
# and link each one to a peer node in the tunnelxsketch one so 
# we can better handle centreline structures properly
# we could have each centrelinenode have a connected peer in the 
# then this lower node doesn't have any paths in it

# implement nodeconnzsetrelative
# the areas are going to need sensible triangulating, 
#   some kind of nice grid that works on other faces
# sketchgraphicspanel.GUpdateSymbolLayout(); (we don't know how to mark symbols)
# convert the skframes into floor sketches below the connective bits
 

class sd0class:
	static func sd0(a, b):
		return a[0] < b[0]

func maketunnelxnetwork(nodepoints, onepathpairs, xctunnelxtube):
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
			var dp0i = xclinkintermediatenodes[i][0]
			var dp1i = xclinkintermediatenodes[i][-1]
			p0i = lerp(p0, p1, dp0i.z) + Vector3(dp0i.x, dp0i.y, 0.0)
			#p0i = xctunnelxtube.intermedpointpos(p0, p1, xclinkintermediatenodes[i][0])
			p1i = lerp(p0, p1, dp1i.z) + Vector3(dp1i.x, dp1i.y, 0.0)

		var vec30 = p0i - p0
		var vec0 = Vector2(vec30.x, vec30.y)
		var vec31 = p1 - p1i
		var vec1 = Vector2(vec31.x, vec31.y)

		Lpathvectorseq[i0].push_back([rad2deg(vec0.angle()), i*2])
		Lpathvectorseq[i1].push_back([rad2deg((-vec1).angle()), i*2+1])

	if onepathpairs != null:
		var Npaths = len(onepathpairs)/2
		for i in range(Npaths):
			var i0 = onepathpairs[i*2]
			var i1 = onepathpairs[i*2+1]
			var vec3 = nodepoints[i1] - nodepoints[i0]
			var vec = Vector2(vec3.x, vec3.y)
			Lpathvectorseq[i0].push_back([vec.angle(), Ndrawinglinks*2 + i*2])
			Lpathvectorseq[i1].push_back([(-vec).angle(), Ndrawinglinks*2 + i*2+1])


	var res = { }
	for i in nodepoints.keys():
		var pathvectorseq = Lpathvectorseq[i]
		pathvectorseq.sort_custom(sd0class, "sd0")
		var pathvectorseqI = [ ]
		for jp in pathvectorseq:
			pathvectorseqI.push_back(jp[1])
		res[i] = pathvectorseqI
	return res



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
			assert (onepathpairs[piv] == opn)
			var pivother = piv + (1 if (piv % 2) == 0 else -1)
			var opnother = onepathpairs[pivother]
			if opnother in opnvisited:
				continue
			var pathlen = Vector2(nodepoints[opn].x - nodepoints[opnother].x, nodepoints[opn].y - nodepoints[opnother].y).length()
			var nodeconnzsetrelative = 0.0
			proxqueue.push_back([qmin[0] + pathlen, opnother, qmin[2] + nodeconnzsetrelative])
	return closestcentrelinenodes
	

func updateznodes(xctunnelxdrawing, xctunnelxtube, bflatteninzfor2Dviewing=false):
	var nodepoints = xctunnelxdrawing.nodepoints
	var Lpathvectorseq = maketunnelxnetwork(nodepoints, null, xctunnelxtube)
	var nextnodepoints = { }
	var lfloordownfromcentrelineoffset = floordownfromcentrelineoffset*(1/tunnelxZscaledown if bflatteninzfor2Dviewing else 1.0)
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
			var newz = zaltsum/tweight - lfloordownfromcentrelineoffset
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
				elif sk.area_signal == "rock" or sk.area_signal == "hole":
					pass
				elif sk.area_signal == "dropdown":
					print("unhandled area signal ", sk.area_signal)
				else:
					print("unprogrammed area signal ", sk.area_signal)

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
		if sk.linestyle == "centreline":
			conepathpairs.push_back(nodeidsmap[sk.from])
			conepathpairs.push_back(nodeidsmap[sk.to])

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


func makedrawinglinksDL(skpaths, nodeidsmap, spbasis, xcdrawinglink, xcsectormaterials, xclinkintermediatenodes):
	var drawinglinks = [ ]
	for sk in skpaths:
		xcdrawinglink.push_back(nodeidsmap[sk.from])
		xcdrawinglink.push_back(nodeidsmap[sk.to])

		if sk.linestyle == "connective" and (sk.area_signal == "rock" or sk.area_signal == "hole"):
			xcsectormaterials.push_back("connective_" + sk.area_signal)
		else:
			xcsectormaterials.push_back(sk.linestyle)
		xclinkintermediatenodes.push_back(Polynets.intermediatedrawnpoints(sk.pts, spbasis))
	return drawinglinks
	

var linestyleboundaries = [ "wall", "estwall", "detail", "pitchbound", "ceilingbound", "invisible" ]

func Sinnerconnectivenetwork(rootinnerconnectives, Lpathvectorseq, xcdrawinglink, linestyles):
	var innerconnectivesM = { }
	for innerconnective in rootinnerconnectives:
		if innerconnectivesM.has(innerconnective):
			continue
		var innerconnectivestack = [ innerconnective ]
		while len(innerconnectivestack) != 0:
			var linnerconnective = innerconnectivestack.pop_back()
			if innerconnectivesM.has(linnerconnective):
				continue
			innerconnectivesM[linnerconnective] = 1
			var linnerconnectiveo = linnerconnective + (1 if ((linnerconnective%2) == 0) else -1)
			var copn = xcdrawinglink[linnerconnectiveo]
			var CNpathvectorseq = Lpathvectorseq[copn]
			if len(CNpathvectorseq) == 1:
				continue
			var cj = CNpathvectorseq.find(linnerconnectiveo)
			assert (cj != -1)
			for k in range(len(CNpathvectorseq)):
				var cjm1 = (len(CNpathvectorseq)-1 if cj == 0 else cj-1)
				var linestylem1 = linestyles[int(CNpathvectorseq[cjm1]/2)]
				if linestyleboundaries.has(linestylem1):
					break
				cj = cjm1
			for k in range(len(CNpathvectorseq)):
				var cjp = ((cj + k)%len(CNpathvectorseq))
				var linestylep = linestyles[int(CNpathvectorseq[cjp]/2)]
				if linestyleboundaries.has(linestylep):
					break
				if linestylep.begins_with("connective"):
					innerconnectivestack.push_back(CNpathvectorseq[cjp])
	return innerconnectivesM.keys()

func SArealinkssequence(idl, Lpathvectorseq, xcdrawinglink, linestyles):
	var seq = [ ]
	var nodeseq = [ ]
	var rootinnerconnectives = [ ]
	while (len(seq) == 0 or seq[0] != idl) and (len(seq) < len(xcdrawinglink) + 10):
		var idlo = idl + (1 if ((idl%2) == 0) else -1)
		var opn = xcdrawinglink[idlo]
		seq.push_back(idl)
		nodeseq.push_back(opn)
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
			elif linestyleL.begins_with("connective"):
				rootinnerconnectives.push_back(idloL)
		idl = idloB
	
	var connectives = Sinnerconnectivenetwork(rootinnerconnectives, Lpathvectorseq, xcdrawinglink, linestyles)
	var area_signal = ""
	for conn in connectives:
		var linestyleC = linestyles[int(conn/2)]
		if linestyleC == "connective_rock":
			area_signal = "rock"
		elif linestyleC == "connective_hole" and area_signal == "":
			area_signal = "hole"
	return { "seq":seq, "nodeseq":nodeseq, "connectives":connectives, "area_signal":area_signal }
	

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

func SAreatrimtree(dlseq):
	var dlseqTT = [ ]
	for idl in dlseq:
		var idlo = idl + (1 if ((idl%2) == 0) else -1)
		if len(dlseqTT) != 0 and dlseqTT[-1] == idlo:
			dlseqTT.pop_back()
		else:
			dlseqTT.push_back(idl)
	while len(dlseqTT) >= 2 and dlseqTT[-1] == dlseqTT[0] + (1 if ((dlseqTT[0]%2) == 0) else -1):
		dlseqTT.pop_back()
		dlseqTT.pop_front()
	return dlseqTT
	

func UpdateSAreas(xctunnelxdrawing, xctunnelxtube):
	var nodepoints = xctunnelxdrawing.nodepoints
	var xclinkintermediatenodes = xctunnelxtube.xclinkintermediatenodes
	var Lpathvectorseq = maketunnelxnetwork(nodepoints, null, xctunnelxtube)
	var xcdrawinglink = xctunnelxtube.xcdrawinglink
	var linestyles = xctunnelxtube.xcsectormaterials
	var Ndrawinglinks = len(xcdrawinglink)/2
	var drawinglinksvisited = { }
	var surfaceTools = [ ]
	for idl in range(Ndrawinglinks*2):
		var i = int(idl/2)
		if (not (linestyles[i] in linestyleboundaries)) or drawinglinksvisited.has(idl):
			continue
		var dlseqM = SArealinkssequence(idl, Lpathvectorseq, xcdrawinglink, linestyles)
		var dlseq = dlseqM["seq"]
		for ldil in dlseq:
			assert (not drawinglinksvisited.has(ldil))
			drawinglinksvisited[ldil] = 1
		if dlseqM.get("area_signal", "") == "rock" or dlseqM.get("area_signal", "") == "hole":
			continue
		var dlseqTT = SAreatrimtree(dlseq)
		if len(dlseqTT) == 0:
			continue
		var areacontour = SAreacontour(dlseqTT, xctunnelxdrawing, xctunnelxtube)
		var rotzminus90 = Basis(Vector3(1,0,0), Vector3(0,0,-1), Vector3(0,1,0))
		areacontour.invert()
		var arr = makegoodtriangulation(areacontour, rotzminus90, idl)
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
	tunnelxlocoffset_local.z = skpathsaabb.position.z - tunnelxZbottom

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
	


func makebadtriangulation(contour, flataligntransform):
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	var rpolygon = [ ]
	for p in contour:
		var tp = flataligntransform.xform(p)
		rpolygon.push_back(Vector2(tp.x, tp.y))
	var polygon = PoolVector2Array(rpolygon)
	if not Geometry.is_polygon_clockwise(polygon):
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
	var contoursliced
	var contourslabindexes
	func sly(i, j):
		if contoursliced[i].x == contoursliced[j].x:
			return contourslabindexes[i] < contourslabindexes[j]  # assumes doubled edge is internal
		return contoursliced[i].x < contoursliced[j].x
		

var discardcclockpolygons = true

func makegoodtriangulation(contour, flataligntransform, Didl):
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

	var nslicerails = int((yhi - ylo)/goodpolyslicewidth + 1.1)
	var slicerailyvals = [ ]
	var slicerailcrossings = [ ]
	var slicerailcrossingflags = [ ]
	for i in range(nslicerails):
		var ydouble = lerp(ylo - goodpolyslicewidth/2, yhi + goodpolyslicewidth/2, (i+1.0)/(nslicerails+2))
		slicerailyvals.push_back(Vector3(0, ydouble, 0))
		slicerailcrossings.push_back([])
		slicerailcrossingflags.push_back([])
		
	var p0 = rcontour[-1]
	var islice0 = 0
	while islice0 < len(slicerailyvals) and slicerailyvals[islice0].y < p0.y:
		islice0 += 1

	var contoursliced = [ ]
	var contourslabindexes = [ ]
	for p in rcontour:
		assert (islice0 == len(slicerailyvals) or p0.y <= slicerailyvals[islice0].y)
		assert (islice0 == 0 or p0.y > slicerailyvals[islice0-1].y)
		if p.y > p0.y:
			while islice0 < len(slicerailyvals) and slicerailyvals[islice0].y < p.y:
				var lam = inverse_lerp(p0.y, p.y, slicerailyvals[islice0].y)
				slicerailcrossings[islice0].push_back(len(contoursliced))
				slicerailcrossingflags[islice0].push_back(0)
				contoursliced.push_back(Vector3(lerp(p0.x, p.x, lam), slicerailyvals[islice0].y, lerp(p0.z, p.z, lam)))
				islice0 += 1
				contourslabindexes.push_back(islice0)
		else:
			while islice0 >= 1 and slicerailyvals[islice0-1].y >= p.y:
				islice0 -= 1
				var lam = inverse_lerp(p0.y, p.y, slicerailyvals[islice0].y)
				slicerailcrossings[islice0].push_back(len(contoursliced))
				slicerailcrossingflags[islice0].push_back(0)
				contoursliced.push_back(Vector3(lerp(p0.x, p.x, lam), slicerailyvals[islice0].y, lerp(p0.z, p.z, lam)))
				contourslabindexes.push_back(islice0)
		contoursliced.push_back(p)
		contourslabindexes.push_back(islice0)
		p0 = p

	assert (len(contoursliced) == len(contourslabindexes))
	var SyX = SslypolygonX.new()
	SyX.contoursliced = contoursliced
	SyX.contourslabindexes = contourslabindexes
	for islicerail in range(len(slicerailcrossings)):
		var slicerailcrossingsL = slicerailcrossings[islicerail]
		slicerailcrossingsL.sort_custom(SyX, "sly")

	if discardcclockpolygons:
		var Nrailseenasclock = 0
		var Nedgedoubles = 0
		for islicerail in range(len(slicerailcrossings)):
			var slicerailcrossingsL = slicerailcrossings[islicerail]
			assert ((len(slicerailcrossingsL)%2) == 0)
			if len(slicerailcrossingsL) == 0:
				continue
			if Didl == 5383 and islicerail == 2:
				print("  dddd")
				for Di in slicerailcrossingsL:
					print(Di, contoursliced[Di], contourslabindexes[Di])
			for j in range(0, len(slicerailcrossingsL), 2):
				if j == 0 or j == len(slicerailcrossingsL) - 2:
					if not (contoursliced[slicerailcrossingsL[j]].x < contoursliced[slicerailcrossingsL[j+1]].x):
						Nedgedoubles += 1
				var iiB = slicerailcrossingsL[j]
				var ciB = contourslabindexes[iiB]
				var iiE = slicerailcrossingsL[j+1]
				var ciE = contourslabindexes[iiE]
				assert ((contoursliced[iiB].y == slicerailyvals[islicerail].y) and (contoursliced[iiE].y == slicerailyvals[islicerail].y))
				assert (ciB == islicerail or ciB == islicerail+1)
				assert (ciE == islicerail or ciE == islicerail+1)
				if ciB == islicerail or ciE == islicerail+1:
					Nrailseenasclock += 1
		if Nrailseenasclock != 0:
			return [ ]
		else:
			assert (Nedgedoubles == 0)

			

	var slabs = [ ]
	for islicerail in range(len(slicerailcrossings)):
		var slicerailcrossingsL = slicerailcrossings[islicerail]
		var slicerailcrossingflagsL = slicerailcrossingflags[islicerail]
		
		if Didl == 1755 and islicerail == 16:
			for Di in slicerailcrossingsL:
				print(Di, contoursliced[Di], contourslabindexes[Di])
			print(slicerailcrossingsL)
		
		for j in range(len(slicerailcrossingsL)):
			var i0 = slicerailcrossingsL[j]
			assert (contoursliced[i0].y == slicerailyvals[islicerail].y)
			var isliceslab = contourslabindexes[i0]
			assert (isliceslab == islicerail or isliceslab == islicerail+1)
			var slabflagL = 2 if isliceslab == islicerail+1 else 1
			if (slicerailcrossingflagsL[j] & slabflagL) != 0:
				continue
			slicerailcrossingflagsL[j] |= slabflagL
			var slabi = [ i0 ]
			var i = i0
			while len(slabi) < len(contourslabindexes):
				while contourslabindexes[i] == isliceslab:
					assert (isliceslab == 0 or (slicerailyvals[isliceslab-1].y <= contoursliced[i].y))
					assert (isliceslab == len(slicerailyvals) or (contoursliced[i].y <= slicerailyvals[isliceslab].y))
					i = (i+1) % len(contourslabindexes)
					slabi.push_back(i)
				assert (contourslabindexes[i] == isliceslab+1 or contourslabindexes[i] == isliceslab-1)
				var btopgoingright = (contourslabindexes[i] == isliceslab+1)
				var isliceslabSide = isliceslab if btopgoingright else isliceslab-1
				assert (isliceslabSide >= 0 and isliceslabSide < len(slicerailyvals))
				var slabflagA = 1 if btopgoingright else 2
				assert (contoursliced[i].y == slicerailyvals[isliceslabSide].y)
				var slicerailcrossingsA = slicerailcrossings[isliceslabSide]
				var slicerailcrossingflagsA = slicerailcrossingflags[isliceslabSide]
				var jc = slicerailcrossingsA.find(i)
				assert (jc != -1)
				assert ((slicerailcrossingflagsA[jc] & slabflagA) == 0)
				slicerailcrossingflagsA[jc] |= slabflagA
				var jc1 = jc+1 if btopgoingright else jc-1
				assert ((jc1 < len(slicerailcrossingflagsA)) if btopgoingright else (jc1 >= 0))
				var i1 = slicerailcrossingsA[jc1]
				assert (contourslabindexes[i1] == isliceslab)
				if (slicerailcrossingflagsA[jc1] & slabflagA) != 0:
					assert (islicerail == isliceslabSide and i1 == i0)
					break
				slicerailcrossingflagsA[jc1] |= slabflagA
				slabi.push_back(i1)
				i = i1
			slabs.push_back(slabi)


	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	var meshvertex = [ ]
	var meshuv = [ ]
	for p in contoursliced:
		meshuv.push_back(Vector2(p.x, p.y))
		meshvertex.push_back(flataligntransform.xform_inv(p))
	arr[Mesh.ARRAY_VERTEX] = PoolVector3Array(meshvertex)
	arr[Mesh.ARRAY_TEX_UV] = PoolVector2Array(meshuv)
	var meshindex = [ ]
	for isliceslab in range(len(slabs)):
		var slabi = slabs[isliceslab]
		var slabpoly = [ ]
		for k in slabi:
			slabpoly.push_back(meshuv[k])
		var pi = Geometry.triangulate_polygon(slabpoly)
		if not pi:
			print("bad slab triangulation ", isliceslab, " ", slabi)
			#for k in slabi:
			#	print(k, " ", contourslabindexes[k], meshuv[k])
		for ki in pi:
			meshindex.push_back(slabi[ki])
	arr[Mesh.ARRAY_INDEX] = PoolIntArray(meshindex)
	return arr


