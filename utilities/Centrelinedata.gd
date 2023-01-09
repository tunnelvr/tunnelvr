class_name Centrelinedata

# "C:\Program Files (x86)\Survex\aven.exe" Ireby\Ireby2\Ireby2.svx
# python surveyscans\convertdmptojson.py Ireby\Ireby2\Ireby2.3d
# python convertdmptotunnelvrjson.py -3 skirwith/skirwith-cave.3d -a skirwith/Dskirwith_jgtslapdash.json
# [remember to copy the 3d file from the source directory]
# ssh godot@proxmox.dynamicdevices.co.uk -p 23

const makecentrelinehextubes = false

static func sketchdatadictlistfromcentreline(centrelinefile, perfectoverlayavoidingoffset):
	print("Opening centreline file ", centrelinefile)
	var centrelinedatafile = File.new()
	centrelinedatafile.open(centrelinefile, File.READ)
	var centrelinedata = parse_json(centrelinedatafile.get_line())
	if centrelinedata == null:
		return null

	var stationpointscoords = centrelinedata.stationpointscoords
	var stationpointsnamesorg = centrelinedata.stationpointsnames
	var legsconnections = centrelinedata.legsconnections
	var legsstyles = centrelinedata.legsstyles

	var bb = [ stationpointscoords[0], stationpointscoords[1], stationpointscoords[2], 
			   stationpointscoords[0], stationpointscoords[1], stationpointscoords[2] ]
	for i in range(len(stationpointsnamesorg)):
		for j in range(3):
			bb[j] = min(bb[j], stationpointscoords[i*3+j])
			bb[j+3] = max(bb[j+3], stationpointscoords[i*3+j])
	print("svx bounding box xyzlo ", [bb[0], bb[1], bb[2]], " hi ", [bb[3], bb[4], bb[5]])
	var bbcenvec = Vector3((bb[0]+bb[3])/2, (bb[1]+bb[4])/2, (bb[2] - 1) - perfectoverlayavoidingoffset)

	var stationpointsnames = [ ]
	var stationpoints = [ ]
	var stationnodepoints = { }
	var nsplaystations = 0
	for i in range(len(stationpointsnamesorg)):
		var stationpointname = stationpointsnamesorg[i].replace(".", ",")   # dots not allowed in node name, but commas are
		
		# see splaystationnoderegex for ourcoding from cusseypot
		# but other times splays come in as blank
		# we should have labelled splay explicitly on load
		if stationpointname == "":
			stationpointname = "%ds" % i
		
		if Tglobal.splaystationnoderegex != null and Tglobal.splaystationnoderegex.search(stationpointname):
			nsplaystations += 1
			
		stationpointsnames.push_back(stationpointname)
		var stationpoint = Vector3(stationpointscoords[i*3], stationpointscoords[i*3+1], stationpointscoords[i*3+2])
		stationpoints.push_back(stationpoint)
		stationnodepoints[stationpointname] = stationpoint

	var makecentrelrudsplays = (nsplaystations < len(stationpointsnamesorg) - nsplaystations)
	print("makecentrelrudsplays: ", makecentrelrudsplays, " for nsplaystations:", nsplaystations, " out of ", len(stationpointsnamesorg), " stations")

	var centrelinelegs = [ ]
	for i in range(len(legsstyles)):
		if stationpointsnames[legsconnections[i*2]] != "" and stationpointsnames[legsconnections[i*2+1]] != "":
			centrelinelegs.push_back(stationpointsnames[legsconnections[i*2]])
			centrelinelegs.push_back(stationpointsnames[legsconnections[i*2+1]])

	print("makecentrelrudsplays: ", makecentrelrudsplays)
	if makecentrelrudsplays:
		var ilrud = 1
		var xsectgps = centrelinedata.xsectgps
		for j in range(len(xsectgps)):
			var xsectgp = xsectgps[j]
			var xsectindexes = xsectgp.xsectindexes
			var xsectrightvecs = xsectgp.xsectrightvecs
			var xsectlruds = xsectgp.xsectlruds

			for i in range(len(xsectindexes)):
				var xl = max(0.1, xsectlruds[i*4+0])
				var xr = max(0.1, xsectlruds[i*4+1])
				var xu = max(0.1, xsectlruds[i*4+2])
				var xd = max(0.1, xsectlruds[i*4+3])

				var spnleft = "%dls" % ilrud
				var spnright = "%drs" % ilrud
				var spnup = "%dus" % ilrud
				var spndown = "%dds" % ilrud

				var p = stationpoints[xsectindexes[i]]
				var spn = stationpointsnames[xsectindexes[i]]
				var vh = Vector3(xsectrightvecs[i*2], xsectrightvecs[i*2+1], 0)
				var pl = p - vh*xl
				var pr = p + vh*xr
				var pu = p + Vector3(0, 0, xu)
				var pd = p - Vector3(0, 0, xd)

				stationpointsnames.push_back(spnleft)
				stationpoints.push_back(pl)
				stationnodepoints[spnleft] = pl
				stationpointsnames.push_back(spnright)
				stationpoints.push_back(pr)
				stationnodepoints[spnright] = pr
				stationpointsnames.push_back(spnup)
				stationpoints.push_back(pu)
				stationnodepoints[spnup] = pu
				stationpointsnames.push_back(spndown)
				stationpoints.push_back(pd)
				stationnodepoints[spndown] = pd
				centrelinelegs.push_back(spn)
				centrelinelegs.push_back(spnleft)
				centrelinelegs.push_back(spn)
				centrelinelegs.push_back(spnright)
				centrelinelegs.push_back(spn)
				centrelinelegs.push_back(spnup)
				centrelinelegs.push_back(spn)
				centrelinelegs.push_back(spndown)
				ilrud += 1

			
	var additionalproperties = { "stationnamecommonroot":findcommonroot(stationnodepoints), 
								 "svxp0":centrelinedata["svxp0"],
								 "headdate":centrelinedata["headdate"], 
								 "cs":centrelinedata["cs"] }

	var rotzminus90 = Basis(Vector3(1,0,0), Vector3(0,0,-1), Vector3(0,1,0))
	var centrelinetransformpos = Transform(rotzminus90, -rotzminus90.xform(bbcenvec))
	var xcdrawingcentreline = { "name":"centreline2", 
								"xcresource":"centrelinedata", 
								"drawingtype":DRAWING_TYPE.DT_CENTRELINE, 
								"drawingvisiblecode":DRAWING_TYPE.VIZ_XCD_HIDE,
								"transformpos":centrelinetransformpos, 
								"nodepoints":stationnodepoints,
								"onepathpairs":centrelinelegs, 
								"additionalproperties":additionalproperties
							  }
	var xcdrawings = [ xcdrawingcentreline ]
	var xctubes = [ ]
	if makecentrelinehextubes:
		var xsectgps = centrelinedata.xsectgps
		var hexonepathpairs = [ "hl","hu", "hu","hv", "hv","hr", "hr","he", "he","hd", "hd","hl"]
		var hextubepairs = ["hl", "hl",  "hr", "hr" ]
		var xcsectormaterials = [ "mediumrock", "partialrock" ]
		for j in range(len(xsectgps)):
			var xsectgp = xsectgps[j]
			var xsectindexes = xsectgp.xsectindexes
			var xsectrightvecs = xsectgp.xsectrightvecs
			var xsectlruds = xsectgp.xsectlruds

			var prevsname = null
			for i in range(len(xsectindexes)):
				var sname = stationpointsnames[xsectindexes[i]]+"t"+String(i)+"s"+String(j)
				var hexnodepoints = { }
				var xl = max(0.1, xsectlruds[i*4+0])
				var xr = max(0.1, xsectlruds[i*4+1])
				var xu = max(0.1, xsectlruds[i*4+2])
				var xd = max(0.1, xsectlruds[i*4+3])
				hexnodepoints["hl"] = Vector3(-xl, 0, 0)
				hexnodepoints["hr"] = Vector3(xr, 0, 0)
				hexnodepoints["hu"] = Vector3(-xl/2, xu, 0)
				hexnodepoints["hv"] = Vector3(+xr/2, xu, 0)
				hexnodepoints["hd"] = Vector3(-xl/2, -xd, 0)
				hexnodepoints["he"] = Vector3(+xr/2, -xd, 0)
				var p = centrelinetransformpos.xform(stationpoints[xsectindexes[i]])
				var ang = Vector2(xsectrightvecs[i*2], -xsectrightvecs[i*2+1]).angle()
				var xcdata = { "name":sname, 
							   "xcresource":"station_"+sname, 
							   "drawingtype":DRAWING_TYPE.DT_XCDRAWING, 
							   "drawingvisiblecode":DRAWING_TYPE.VIZ_XCD_HIDE,
							   "transformpos":Transform(Basis().rotated(Vector3(0,-1,0), ang), p), 
							   "nodepoints":hexnodepoints,
							   "onepathpairs":hexonepathpairs.duplicate()
							 }
				xcdrawings.push_back(xcdata)
				#xcvizstates[sname] = DRAWING_TYPE.VIZ_XCD_HIDE

				if prevsname != null:
					var xctdata = { "tubename":"**notset",
									"xcname0":prevsname, 
									"xcname1":sname,
									"xcdrawinglink":hextubepairs.duplicate(),
									"xcsectormaterials":xcsectormaterials.duplicate()
								  }
					xctdata["tubename"] = "hextube_"+prevsname+"_"+sname
					xctubes.push_back(xctdata)
				prevsname = sname

	#xcdrawinglist.push_back({ "xcvizstates":xcvizstates, "updatetubeshells":updatetubeshells })
	return { "xcdrawings":xcdrawings, "xctubes":xctubes }
	

static func findcommonroot(nodepoints):
	var commonroot = null
	for xcname in nodepoints:
		if Tglobal.splaystationnoderegex == null or not Tglobal.splaystationnoderegex.search(xcname):
			if xcname.begins_with(","):
				pass
			elif commonroot == null:
				commonroot = xcname.to_lower()
			else:
				var prevcommonroot = commonroot
				while commonroot != "" and not xcname.to_lower().begins_with(commonroot):
					commonroot = commonroot.left(len(commonroot)-1)
				if commonroot == "" and prevcommonroot != "":
					print("common root lost at ", xcname.to_lower(), " when was ", prevcommonroot)
	if commonroot != null:
		commonroot = commonroot.left(commonroot.find_last(",")+1)
	else:
		commonroot = ""
	print("stationlabels common root: ", commonroot)
	return commonroot

static func centrelinenodeassociation(nodepointsfrom, nodepointsto, backlinklist):
	var nodetoname0 = backlinklist[0]
	var nodefromname0 = backlinklist[1]
	var nodetoname0commas = [ -1 ]
	while len(nodetoname0commas) == 1 or nodetoname0commas[-1] != -1:
		nodetoname0commas.push_back(nodetoname0.find(",", nodetoname0commas[-1]+1))
	nodetoname0commas.pop_back()
	var nodefromname0commas = [ -1 ]
	while len(nodefromname0commas) == 1 or nodefromname0commas[-1] != -1:
		nodefromname0commas.push_back(nodefromname0.find(",", nodefromname0commas[-1]+1))
	nodefromname0commas.pop_back()
	while len(nodetoname0commas) > 1 and len(nodefromname0commas) > 1 and nodetoname0.right(nodetoname0commas[-1]+1) == nodefromname0.right(nodefromname0commas[-1]+1):
		nodetoname0commas.pop_back()
		nodefromname0commas.pop_back()
	var nodetohead = nodetoname0.left(nodetoname0commas[-1]+1)
	var nodefromhead = nodefromname0.left(nodefromname0commas[-1]+1)

	var nodepointsmap = { }
	var nnonsplaynodes = 0
	for nodefromname in nodepointsfrom:
		var issplaynode = Tglobal.splaystationnoderegex != null and Tglobal.splaystationnoderegex.search(nodefromname)
		if not issplaynode:
			nnonsplaynodes += 1
			if nodefromname.begins_with(nodefromhead):
				var nodetoname = nodetohead + nodefromname.right(len(nodefromhead))
				if nodepointsto.has(nodetoname):
					nodepointsmap[nodefromname] = nodetoname
	assert (nodepointsmap.get(nodefromname0) == nodetoname0)
	print("centrelinenodeassociation matches ", len(nodepointsmap), " of ", nnonsplaynodes, " nodes")
	return nodepointsmap
	

static func xcdrawingsforcentreline(centrelinefrom, sketchsystem):
	var xcdrawingsc = [ ]
	var xcdrawings = sketchsystem.get_node("XCdrawings")
	for xcdrawing in xcdrawings.get_children():
		if xcdrawing.drawingtype == DRAWING_TYPE.DT_XCDRAWING or xcdrawing.drawingtype == DRAWING_TYPE.DT_ROPEHANG:
			xcdrawingsc.push_back(xcdrawing)
	return xcdrawingsc

static func xcconnectedtubes(xcdrawingsc):
	var xctubenames = [ ]
	for xcdrawing in xcdrawingsc:
		for xctube in xcdrawing.xctubesconn:
			xctubenames.append(xctube.get_name())
	return xctubenames
	
static func xcanchorsforcentreline(centrelinefrom, sketchsystem):
	var xcdrawingfloor = [ ]
	var xcdrawings = sketchsystem.get_node("XCdrawings")
	for xcanchortube in centrelinefrom.xctubesconn:
		var xcanchordrawing = xcdrawings.get_node(xcanchortube.xcname1 if xcanchortube.xcname0 == centrelinefrom.get_name() else xcanchortube.xcname0)
		if xcanchordrawing.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE:
			xcdrawingfloor.push_back(xcanchordrawing)
	return xcdrawingfloor

static func centrelinepassagedistort(centrelineto, sketchsystem):
	var xcdrawings = sketchsystem.get_node("XCdrawings")
	var clconnectnodeto = centrelineto.xccentrelineconnectstofloor(xcdrawings)
	assert (clconnectnodeto == 2)
	var xcdatalistA = [ ]
	for xcctube in centrelineto.xctubesconn:
		var centrelinefrom = xcdrawings.get_node(xcctube.xcname1 if xcctube.xcname0 == centrelineto.get_name() else xcctube.xcname0)
		assert (centrelinefrom.drawingtype == DRAWING_TYPE.DT_CENTRELINE)
		var clconnectnodefrom = centrelinefrom.xccentrelineconnectstofloor(sketchsystem.get_node("XCdrawings"))
		assert (clconnectnodefrom != 2)
		var nodepointsmap = centrelinenodeassociation(centrelinefrom.nodepoints, centrelineto.nodepoints, xcctube.xcdrawinglink)

		var sumtranslation = Vector3(0, 0, 0)
		for nodefromname in nodepointsmap:
			var nodetoname = nodepointsmap[nodefromname]
			var pto = centrelineto.transform * centrelineto.nodepoints[nodetoname]
			var pfrom = centrelinefrom.transform * centrelinefrom.nodepoints[nodefromname]
			sumtranslation += (pto - pfrom)
		var avgtranslation = sumtranslation * (1.0/len(nodepointsmap))
		
		var xcdatalist = [ ]
		var xcdrawingsc = xcdrawingsforcentreline(centrelinefrom, sketchsystem)
		for xcdrawing in xcdrawingsc:
			var txcdata = { "name":xcdrawing.get_name(), 
							"prevtransformpos":xcdrawing.transform, 
							"transformpos":Transform(xcdrawing.transform.basis, xcdrawing.transform.origin + avgtranslation) }
			xcdatalist.append(txcdata)

		var updatetubeshells = [ ]
		var xctubenames = xcconnectedtubes(xcdrawingsc)
		xctubenames.sort()
		var prevxctubename = ""
		var xctubes = sketchsystem.get_node("XCtubes")
		for xctubename in xctubenames:
			if xctubename != prevxctubename:
				var xctube = xctubes.get_node(xctubename)
				updatetubeshells.push_back({ "tubename":xctubename, "xcname0":xctube.xcname0, "xcname1":xctube.xcname1 })
				prevxctubename = xctubename
		xcdatalist.append({"xcvizstates":{ }, "updatetubeshells":updatetubeshells, "updatexcshells":[] })
		xcdatalistA.append_array(xcdatalist)

		var xcdataanchortubes = [ ]
		for xcanchortube in centrelinefrom.xctubesconn:
			if xcanchortube.xcname0 == centrelinefrom.get_name() and xcdrawings.get_node(xcanchortube.xcname1).drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE:
				var prevdrawinglinks = [ ]
				var mappeddrawinglinks = [ ]
				for j in range(0, len(xcanchortube.xcdrawinglink), 2):
					prevdrawinglinks.push_back(xcanchortube.xcdrawinglink[j])
					prevdrawinglinks.push_back(xcanchortube.xcdrawinglink[j+1])
					prevdrawinglinks.push_back(xcanchortube.xcsectormaterials[j/2])
					prevdrawinglinks.push_back(null)
					mappeddrawinglinks.push_back(nodepointsmap[xcanchortube.xcdrawinglink[j]])
					mappeddrawinglinks.push_back(xcanchortube.xcdrawinglink[j+1])
					mappeddrawinglinks.push_back(xcanchortube.xcsectormaterials[j/2])
					mappeddrawinglinks.push_back(null)
					
				var xcdataanchortubeorg = { "tubename":xcanchortube.get_name(), 
											"xcname0":centrelinefrom.get_name(), 
											"xcname1":xcanchortube.xcname1, 
											"prevdrawinglinks":prevdrawinglinks,
											"newdrawinglinks":[ ] }
				var xcdataanchortubenew = { "tubename":"**notset", 
											"xcname0":centrelineto.get_name(), 
											"xcname1":xcanchortube.xcname1, 
											"prevdrawinglinks":[ ],
											"newdrawinglinks":mappeddrawinglinks }
				sketchsystem.setnewtubename(xcdataanchortubenew)
				xcdataanchortubes.push_back(xcdataanchortubeorg)
				xcdataanchortubes.push_back(xcdataanchortubenew)

				xcdataanchortubes.push_back({"xcvizstates":{ }, "updatetubeshells":[ 
									{ "tubename":xcdataanchortubenew["tubename"], 
									  "xcname0":xcdataanchortubenew["xcname0"], 
									  "xcname1":xcdataanchortubenew["xcname1"] 
									} ] })
		xcdatalistA.append_array(xcdataanchortubes)
		
		var prevcdrawinglinks = [ ]
		for j in range(0, len(xcctube.xcdrawinglink), 2):
			prevcdrawinglinks.push_back(xcctube.xcdrawinglink[j])
			prevcdrawinglinks.push_back(xcctube.xcdrawinglink[j+1])
			prevcdrawinglinks.push_back(xcctube.xcsectormaterials[j/2])
			prevcdrawinglinks.push_back(null)
		xcdatalistA.append({ "tubename":xcctube.get_name(), 
							 "xcname0":xcctube.xcname0, 
							 "xcname1":xcctube.xcname1, 
							 "prevdrawinglinks":prevcdrawinglinks, 
							 "newdrawinglinks":[ ] })

		xcdatalistA.append({ "name":centrelinefrom.get_name(), 
							 "prevnodepoints":centrelinefrom.nodepoints.duplicate(),
							 "nextnodepoints":{ }, 
							 "prevonepathpairs":centrelinefrom.onepathpairs.duplicate(),
							 "newonepathpairs": [ ] })

	return xcdatalistA
	
