extends Spatial

onready var sketchsystem = get_node("/root/Spatial/SketchSystem")


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
		nodepoints[nodeidsmap[sk.from]] = sk.pts[0]
		nodepoints[nodeidsmap[sk.to]] = sk.pts[-1]
		if sk.linestyle == "centreline":
			conepathpairs.append(nodeidsmap[sk.from])
			conepathpairs.append(nodeidsmap[sk.to])

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
				var dpz = (sk.pts[i] - p0).dot(vec)/vecsq
				var sp = lerp(p0, p1, dpz)
				var dp = sk.pts[i] - sp
				intermediatepoints.push_back(Vector3(dp.dot(spbasis.x), dp.dot(spbasis.z), dpz))
			drawinglinks.push_back(intermediatepoints)
		else:
			drawinglinks.push_back(null)
	return drawinglinks


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
	sketchsystem.actsketchchange([ xcdata, xctdata ])

