class_name Centrelinedata

# "C:\Program Files (x86)\Survex\aven.exe" Ireby\Ireby2\Ireby2.svx
# python surveyscans\convertdmptojson.py Ireby\Ireby2\Ireby2.3d
# python convertdmptotunnelvrjson.py -3 skirwith/skirwith-cave.3d -a skirwith/Dskirwith_jgtslapdash.json
# [remember to copy the 3d file from the source directory]
# ssh godot@proxmox.dynamicdevices.co.uk -p 23

const makecentrelinehextubes = false

static func sketchdatadictlistfromcentreline(centrelinefile):
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
	var bbcenvec = Vector3((bb[0]+bb[3])/2, (bb[2] - 1), (bb[1]+bb[4])/2)
	print("\n\nbbcenvec ", bbcenvec)

	var stationpointsnames = [ ]
	var stationpoints = [ ]
	var stationnodepoints = { }
	var nsplaystations = 0
	for i in range(len(stationpointsnamesorg)):
		var stationpointname = stationpointsnamesorg[i].replace(".", ",")   # dots not allowed in node name, but commas are
		
		# see splaystatoonnoderegex for ourcoding from cusseypot
		# but other times splays come in as blank
		# we should have labelled splay explicitly on load
		if stationpointname == "":
			stationpointname = "%ds" % i
		
		if Tglobal.splaystationnoderegex != null and Tglobal.splaystationnoderegex.search(stationpointname):
			nsplaystations += 1
			
		stationpointsnames.push_back(stationpointname)
		#nodepoints[k] = Vector3(stationpointscoords[i*3], 8.1+stationpointscoords[i*3+2], -stationpointscoords[i*3+1])
		var stationpoint = Vector3(stationpointscoords[i*3] - bbcenvec.x, 
								   stationpointscoords[i*3+2] - bbcenvec.y, 
								   -(stationpointscoords[i*3+1] - bbcenvec.z))
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
				var vh = Vector3(xsectrightvecs[i*2], 0, -xsectrightvecs[i*2+1])
				var pl = p - vh*xl
				var pr = p + vh*xr
				var pu = p + Vector3(0, xu, 0)
				var pd = p - Vector3(0, xd, 0)

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

			
	var additionalproperties = { "stationnamecommonroot":findcommonroot(stationnodepoints) }
	var xcdrawingcentreline = { "name":"centreline2", 
								"xcresource":"centrelinedata", 
								"drawingtype":DRAWING_TYPE.DT_CENTRELINE, 
								"drawingvisiblecode":DRAWING_TYPE.VIZ_XCD_HIDE,
								"transformpos":Transform(), 
								"nodepoints":stationnodepoints,
								"onepathpairs":centrelinelegs, 
								"additionalproperties":additionalproperties
							  }
	var xcdrawings = [ xcdrawingcentreline ]
	#var xcvizstates = { xcdrawingcentreline["name"]:DRAWING_TYPE.VIZ_XCD_NODES_VISIBLE }
	#var xcvizstates = { xcdrawingcentreline["name"]:DRAWING_TYPE.VIZ_XCD_HIDE }
	#var updatetubeshells = [ ]

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
				var p = stationpoints[xsectindexes[i]]
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
					xctubes.push_back(xctdata)
					#updatetubeshells.push_back({ "tubename":xctdata["tubename"], "xcname0":xctdata["xcname0"], "xcname1":xctdata["xcname1"] })
				prevsname = sname

	#xcdrawinglist.push_back({ "xcvizstates":xcvizstates, "updatetubeshells":updatetubeshells })
	return { "xcdrawings":xcdrawings, "xctubes":xctubes }
	

static func xcdatalistfromwingdata(wingdeffile):
	var f = File.new()
	f.open(wingdeffile, File.READ)
	var k = [ ]
	for j in range(70):
		k.append(f.get_csv_line())
	var sections = [ ]
	var zvals = [ ]
	for i in range(1, 60, 3):
		var pts = [ ]
		var z = float(k[2][i+1])
		for j in range(2, 70):
			assert (z == float(k[j][i+1]))
			pts.append(Vector3(float(k[j][i]), float(k[j][i+2]), 0))
		zvals.append(z)
		sections.append(pts)
	assert(len(sections) == Tglobal.wingmeshuvudivisions)
	
	var nodepairs = [ ]
	for i in range(Tglobal.wingmeshuvvdivisions-1):
		nodepairs.append("p%d"%i)
		nodepairs.append("p%d"%(i+1))
	#var enddrawinglinks = ["p0", "p0", "graphpaper", null,  "p67", "p67", "graphpaper", null]
	var enddrawinglinks = [ ]
	for i in range(Tglobal.wingmeshuvvdivisions):
		enddrawinglinks.append("p%d"%i)
		enddrawinglinks.append("p%d"%i)
		enddrawinglinks.append("graphpaper")
		enddrawinglinks.append(null)
	var xcdrawinglist = [ ]
	var xcvizstates = { }
	var prevsname = null
	var updatetubeshells = [ ]
	for j in range(len(sections)):
		var pts = sections[j]
		var nodepoints = { }
		for i in range(Tglobal.wingmeshuvvdivisions):
			nodepoints["p%d" % i] = pts[i]
		var sname = "ws%d"%j
		var xcdata = { "name":sname, 
					   "drawingtype":DRAWING_TYPE.DT_XCDRAWING, 
					   "transformpos":Transform(Basis(), Vector3(0, 1.2, zvals[j])), 
					   "prevnodepoints":{ },
					   "nextnodepoints":nodepoints,
					   "prevonepathpairs":[ ],
					   "newonepathpairs":nodepairs.duplicate()
					 }
		xcdrawinglist.push_back(xcdata)
		xcvizstates[sname] = DRAWING_TYPE.VIZ_XCD_HIDE
		if j != 0:
			var xctdata = { "tubename":"**notset", 
							"xcname0":prevsname, 
							"xcname1":sname,
							"prevdrawinglinks":[ ],
							"newdrawinglinks":enddrawinglinks.duplicate()
						  }
			xcdrawinglist.push_back(xctdata)
			updatetubeshells.push_back({ "tubename":xctdata["tubename"], "xcname0":xctdata["xcname0"], "xcname1":xctdata["xcname1"] })
		prevsname = sname
	xcdrawinglist.push_back({ "xcvizstates":xcvizstates, "updatetubeshells":updatetubeshells })
	return xcdrawinglist

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
