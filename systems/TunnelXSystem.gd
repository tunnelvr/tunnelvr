extends Spatial

onready var sketchsystem = get_node("/root/Spatial/SketchSystem")

var tunnelx_xcname = null
var tunnelx_tubename = null

# things to do: 
# updateznodes settings going out
# plot edges according to their style and Color
# sketchgraphicspanel.UpdateZNodes();
# sketchgraphicspanel.UpdateSAreas();
# the areas are going to need sensible triangulating, 
#   some kind of nice grid that works on other faces
# sketchgraphicspanel.GUpdateSymbolLayout();
# convert the skframes into floor sketches below the connective bits
# is fixing up and exporting remotely feasible?
# use xcsectormaterials to set the linestyle!

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
			var pathzdiff = 0.0
			proxqueue.push_back([qmin[0] + pathlen, opnother, qmin[2] + pathzdiff])
	return closestcentrelinenodes
	
	
func updateznodes(xctunnelxdrawing, xctunnelxtube):
	var nodepoints = xctunnelxdrawing.nodepoints
	var Lpathvectorseq = maketunnelxnetwork(nodepoints, null, xctunnelxtube)
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

const tunnelxFac = 0.1
const tunnelxZshift = 10.0

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
				var pt = Vector3(float(xp.get_named_attribute_value("X"))*tunnelxFac, float(xp.get_named_attribute_value("Y"))*tunnelxFac, tunnelxZshift)
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
					print("TEXT ", sk.pctext_style, " ", sk.pctext if len(sk.pctext) < 20 else len(sk.pctext))
		xp.read()
	sk.pts = PoolVector3Array(pts)
	if subsets:
		sk.subsets = PoolStringArray(subsets)
	return sk
	

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
	

func makexcdata(skpaths, nodeidsmap):
	var nodepoints = { }
	var conepathpairs = [ ]
	for sk in skpaths:
		if not nodepoints.has(nodeidsmap[sk.from]) or sk.linestyle == "centreline":
			nodepoints[nodeidsmap[sk.from]] = sk.pts[0]
		if not nodepoints.has(nodeidsmap[sk.to]) or sk.linestyle == "centreline":
			nodepoints[nodeidsmap[sk.to]] = sk.pts[-1]

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
		drawinglinks.push_back(null)
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



#sketchgraphicspanel.UpdateZNodes();
#sketchgraphicspanel.UpdateSAreas();
#sketchgraphicspanel.GUpdateSymbolLayout(true, visiprogressbar);


func loadtunnelxsketch(fname):
	var xp = XMLParser.new()
	print(xp.open(fname))
	xp.read()
	xp.read()
	xp.read()
	if not (xp.get_node_type() == xp.NODE_ELEMENT and xp.get_node_name() == "tunnelxml"):
		return
	xp.read()
	if not (xp.get_node_type() == xp.NODE_ELEMENT and xp.get_node_name() == "sketch"):
		return
		
	var skpaths = [ ]
	for i in range(10000):
		xp.read()
		if xp.get_node_type() == xp.NODE_ELEMENT_END and xp.get_node_name() == "sketch":
			print("done ", i)
			break
		if xp.get_node_type() == xp.NODE_ELEMENT and xp.get_node_name() == "skpath":
			var sk = skpath(xp)
			skpaths.append(sk)

	var nodeidsmap = makenodeidsmap(skpaths)
	var xcdata = makexcdata(skpaths, nodeidsmap)
	var xctdata = { "tubename":"**notset", 
					"xcname0":xcdata["name"],
					"xcname1":xcdata["name"],
					"prevdrawinglinks":[], 
					"newdrawinglinks":makedrawinglinks(skpaths, nodeidsmap, xcdata["transformpos"].basis)
				   }
	sketchsystem.setnewtubename(xctdata)
	tunnelx_xcname = xcdata["name"]
	tunnelx_tubename = xctdata["tubename"]
	sketchsystem.actsketchchange([ xcdata, xctdata ])

	var xctunnelxdrawing = sketchsystem.get_node("XCdrawings").get_node(tunnelx_xcname)
	var xctunnelxtube = sketchsystem.get_node("XCtubes").get_node(tunnelx_tubename)
	var xczdata = updateznodes(xctunnelxdrawing, xctunnelxtube)
	var xctdataviz = { "xcvizstates": [ ], 
					   "updatetubeshells":[
						   { "tubename":xctunnelxtube.get_name(), "xcname0":xctunnelxtube.xcname0, "xcname1":xctunnelxtube.xcname1 } 
					   ] 
					 }
					
	sketchsystem.actsketchchange([ xczdata, xctdataviz ])

