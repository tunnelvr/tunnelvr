extends Spatial

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
				var pt = Vector3(float(xp.get_named_attribute_value("X")), float(xp.get_named_attribute_value("Y")), 0.0)
				if sk.linestyle == "centreline":
					pt.z = float(xp.get_named_attribute_value("Z"))
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
	

#flagsignlabels)
#flagsignlabels = { }
#	var xctdataviz = { "xcvizstates":{ prevxcname:finishedplanedrawingtype }, 
#					   "updatetubeshells":[
#						{ "tubename":xctdata["tubename"], "xcname0":xctdata["xcname0"], "xcname1":xctdata["xcname1"] } 
#					] }
								

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
		
	var nodepoints = { }
	var conepathpairs = [ ]
	var flagsignlabels = { }
	var skpaths = [ ]
	for i in range(10000):
		xp.read()
		if xp.get_node_type() == xp.NODE_ELEMENT_END and xp.get_node_name() == "sketch":
			print("done ", i)
			break
		if xp.get_node_type() == xp.NODE_ELEMENT and xp.get_node_name() == "skpath":
			var sk = skpath(xp)
			nodepoints["n%d" % sk.from] = sk.pts[0]
			nodepoints["n%d" % sk.to] = sk.pts[-1]
			if sk.linestyle == "centreline":
				flagsignlabels["n%d" % sk.from] = sk.cltail
				flagsignlabels["n%d" % sk.to] = sk.clhead
				conepathpairs.append("n%d" % sk.from)
				conepathpairs.append("n%d" % sk.to)
			skpaths.append(sk)

#			drawinglinks

	var sketchsystem = get_node("/root/Spatial/SketchSystem")
	var rotzminus90 = Basis(Vector3(1,0,0), Vector3(0,0,-1), Vector3(0,1,0))
	var bbcenvec = Vector3()
	var centrelinetransformpos = Transform(rotzminus90, -rotzminus90.xform(bbcenvec))
	var xcdata = { "name":sketchsystem.uniqueXCname("tunnelx"), 
				   "drawingtype":DRAWING_TYPE.DT_CENTRELINE,
				   "drawingvisiblecode":DRAWING_TYPE.VIZ_XCD_PLANE_AND_NODES_VISIBLE,
				   "transformpos":centrelinetransformpos, 
				   "nodepoints":nodepoints, 
				   "onepathpairs":conepathpairs, 
				   "additionalproperties": { "flagsignlabels": flagsignlabels }
				 }
#	var xctdata = { "tubename":"**notset", 
#					"xcname0":xcdata["name"],
#					"xcname1":xcdata["name"],
#					"prevdrawinglinks":[], 
#					"newdrawinglinks":drawinglinks }


	sketchsystem.actsketchchange([ xcdata ])

