extends Spatial

const XCdrawing = preload("res://nodescenes/XCdrawing.tscn")
const XCtube = preload("res://nodescenes/XCtube.tscn")

const linewidth = 0.05

var actsketchchangeundostack = [ ]

const defaultfloordrawing = "http://cave-registry.org.uk/svn/NorthernEngland/ThreeCountiesArea/rawscans/Ireby/DukeStResurvey-drawnup-p3.jpg"

func _ready():
	var floordrawingimg = defaultfloordrawing
	floordrawingimg = "res://surveyscans/greenland/ushapedcave.png"
	var floordrawing = newXCuniquedrawingPaper(floordrawingimg, DRAWING_TYPE.DT_FLOORTEXTURE)
	get_node("/root/Spatial/ImageSystem").fetchpaperdrawing(floordrawing)
		



func findxctube(xcname0, xcname1):
	var xcdrawing0 = get_node("XCdrawings").get_node(xcname0)	
	for xctube in xcdrawing0.xctubesconn:
		assert (xctube.xcname0 == xcname0 or xctube.xcname1 == xcname0)
		if xctube.xcname1 == xcname1:
			return xctube
		if xctube.xcname0 == xcname1:
			return xctube
	return null
	
remote func xctubefromdata(xctdata):
	var xctube = findxctube(xctdata["xcname0"], xctdata["xcname1"])
	if xctube == null:
		var xcdrawing0 = get_node("XCdrawings").get_node(xctdata["xcname0"])
		var xcdrawing1 = get_node("XCdrawings").get_node(xctdata["xcname1"])
		xctdata["m0"] = 1 if xcdrawing1.drawingtype == DRAWING_TYPE.DT_CENTRELINE else 0
		if xctdata["m0"] == 0:
			xctube = newXCtube(xcdrawing0, xcdrawing1)
		else:
			xctube = newXCtube(xcdrawing1, xcdrawing0)
	else:
		xctdata["m0"] = 1 if xctube.xcname0 == xctdata["xcname1"] else 0
	xctube.mergexctrpcdata(xctdata)
	return xctube

func updateworkingshell():
	for xctube in $XCtubes.get_children():
		if not xctube.positioningtube:
			xctube.updatetubeshell($XCdrawings, Tglobal.tubeshellsvisible)
	for xcdrawing in $XCdrawings.get_children():
		if xcdrawing.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
			xcdrawing.updatexctubeshell($XCdrawings, Tglobal.tubeshellsvisible)

func updatecentrelinevisibility():
	get_tree().call_group("gpnoncentrelinegeo", "xcdfullsetvisibilitycollision", not Tglobal.centrelineonly)
	get_node("/root/Spatial/PlanViewSystem").updatecentrelinesizes()
	for centrelinexcdrawing in get_tree().get_nodes_in_group("gpcentrelinegeo"):
		get_node("/root/Spatial/LabelGenerator").makenodelabelstask(centrelinexcdrawing, false)

func changetubedxcsvizmode():
	for xcdrawing in $XCdrawings.get_children():
		if xcdrawing.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
			var xcsvisible = xcdrawing.get_node("XCdrawingplane").visible or Tglobal.tubedxcsvisible or len(xcdrawing.xctubesconn) == 0
			xcdrawing.get_node("XCnodes").visible = xcsvisible
			xcdrawing.get_node("PathLines").visible = xcsvisible
			assert (xcdrawing.get_node("XCdrawingplane").visible != xcdrawing.get_node("XCdrawingplane/CollisionShape").disabled)

func sketchsystemtodict():
	var xcdrawingsData = [ ]
	for xcdrawing in $XCdrawings.get_children():
		xcdrawingsData.append(xcdrawing.exportxcrpcdata())
	var xctubesData = [ ]
	for xctube in $XCtubes.get_children():
		xctubesData.append(xctube.exportxctrpcdata())
	var sketchdatadict = { "xcdrawings":xcdrawingsData,
						   "xctubes":xctubesData
						 }
	var playerMe = get_node("/root/Spatial").playerMe
	sketchdatadict["playerMe"] = { "transformpos":playerMe.global_transform, "headtrans":playerMe.get_node("HeadCam").global_transform }
	return sketchdatadict
	
func savesketchsystem(fname):
	var sketchdatadict = sketchsystemtodict()
	var sketchdatafile = File.new()
	sketchdatafile.open(fname, File.WRITE)
	sketchdatafile.store_var(sketchdatadict)
	sketchdatafile.close()
	print("sssssaved in C:/Users/ViveOne/AppData/Roaming/Godot/app_userdata/tunnelvr")


func getactivefloordrawing():
	var floordrawing = $XCdrawings.get_child(0)  # only one here for now
	#assert (floordrawing.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE)
	return floordrawing


func loadcentrelinefile(centrelinefile):
	print("  want to open file ", centrelinefile)
	var centrelinedrawing = newXCuniquedrawing(DRAWING_TYPE.DT_CENTRELINE, "centreline")
	var centrelinedatafile = File.new()

	centrelinedrawing.xcresource = centrelinefile

	centrelinedatafile.open(centrelinedrawing.xcresource, File.READ)
	var centrelinedata = parse_json(centrelinedatafile.get_line())
	centrelinedrawing.importcentrelinedata(centrelinedata, self)
	#var xsectgps = centrelinedata.xsectgps
	get_node("/root/Spatial/LabelGenerator").makenodelabelstask(centrelinedrawing, true)
	print("default lllloaded")

# to abolish
func sharexcdrawingovernetwork(xcdrawing):
	if Tglobal.connectiontoserveractive:
		rpc("xcdrawingfromdata", xcdrawing.exportxcrpcdata())
		print(xcdrawing.exportxcrpcdata())


func actsketchchange(xcdatalist):
	actsketchchangeL(xcdatalist)
	if Tglobal.connectiontoserveractive:
		if not (len(xcdatalist) == 1 and "rpcoptional" in xcdatalist[0]):
			rpc("actsketchchangeL", xcdatalist)
	
remote func actsketchchangeL(xcdatalist):
	if "undoact" in xcdatalist[0]:
		if len(actsketchchangeundostack) != 0:
			# check this matches
			actsketchchangeundostack.pop_back()
	else:
		if len(actsketchchangeundostack) > 0 and len(actsketchchangeundostack[-1]) == 1 and len(xcdatalist) == 1 \
			and "transformpos" in actsketchchangeundostack[-1][0] and "transformpos" in xcdatalist[0] \
			and actsketchchangeundostack[-1][0].get("name", "*1") == xcdatalist[0].get("name", "*2"):
				actsketchchangeundostack[-1][0]["transformpos"] = xcdatalist[0]["transformpos"]
				actsketchchangeundostack[-1][0].erase("rpcoptional")
		else:
			while len(actsketchchangeundostack) >= 10:
				actsketchchangeundostack.pop_front()
			actsketchchangeundostack.push_back(xcdatalist)
			
	# append to undo stack here
	var xcdrawingstoupdate = { }
	var xctubestoupdate = { }
	for i in range(len(xcdatalist)):
		var xcdata = xcdatalist[i]
		
		if "tubename" in xcdata:
			if xcdata["tubename"] == "**notset":
				xcdata["tubename"] = "XCtube_"+xcdata["xcname0"]+"_"+xcdata["xcname1"]
			var xctube = xctubefromdata(xcdata)
			if len(xctube.xcdrawinglink) == 0 and len(xctube.xcsectormaterials) == 0:
				removeXCtube(xctube)
				xctube.queue_free() 
			else:
				xctubestoupdate[xctube.get_name()] = xctube
				if "materialsectorschanged" in xcdata:
					for j in xcdata["materialsectorschanged"]:
						if j < len(xctube.xcsectormaterials) and j < xctube.get_node("XCtubesectors").get_child_count():
							get_node("/root/Spatial/MaterialSystem").updatetubesectormaterial(xctube.get_node("XCtubesectors").get_child(j), xctube.xcsectormaterials[j], false)
			
		elif "xcvizstates" in xcdata:
			xcdata["prevxcvizstates"] = { }
			for xcdrawingname in xcdata["xcvizstates"]:
				var xcdrawing = $XCdrawings.get_node_or_null(xcdrawingname)
				if xcdrawing != null:
					var drawingplanevisible = xcdrawing.get_node("XCdrawingplane").visible
					var drawingnodesvisible = xcdrawing.get_node("XCnodes").visible
					xcdata["prevxcvizstates"][xcdrawingname] = (1 if drawingplanevisible else 0) + (2 if drawingnodesvisible else 0)
					var drawingvisiblecode = xcdata["xcvizstates"][xcdrawingname]
					if (drawingvisiblecode & 1) != 0:
						xcdrawing.setxcdrawingvisible()
					else:
						xcdrawing.setxcdrawingvisiblehide((drawingvisiblecode & 2) == 0)
			if "updatetubeshells" in xcdata:
				for xct in xcdata["updatetubeshells"]:
					var xctube = findxctube(xct["xcname0"], xct["xcname1"])
					#var xctube = $XCtubes.get_node_or_null(xct["xctubename"])
					if xctube != null:
						xctube.updatetubeshell($XCdrawings, Tglobal.tubeshellsvisible)
			if "updatexcshells" in xcdata:
				for xcdrawingname in xcdata["updatexcshells"]:
					var xcdrawing = $XCdrawings.get_node_or_null(xcdrawingname)
					if xcdrawing != null:
						xcdrawing.updatexctubeshell($XCdrawings, Tglobal.tubeshellsvisible)
						
		else:  # xcdrawing
			assert ("name" in xcdata)
			if "transformpos" in xcdata and not ("prevtransformpos" in xcdata):
				var lxcdrawing = $XCdrawings.get_node_or_null(xcdata["name"])
				if lxcdrawing != null:
					xcdata["prevtransformpos"] = lxcdrawing.global_transform
			var xcdrawing = xcdrawingfromdata(xcdata)
			if "nodepoints" in xcdata or "nextnodepoints" in xcdata or "onepathpairs" in xcdata or "newonepathpairs" in xcdata:
				xcdrawingstoupdate[xcdrawing.get_name()] = xcdrawing
				if len(xcdata.get("prevnodepoints", [])) != 0:
					for xctube in xcdrawing.xctubesconn:
						xctubestoupdate[xctube.get_name()] = xctube

			var tpos = null
			var xcname = null
			var sname = "ClickSound"
			if len(xcdata.get("nextnodepoints", [])) != 0:
				tpos = xcdata["nextnodepoints"].values()[0]
			elif len(xcdata.get("prevnodepoints", [])) != 0:
				tpos = xcdata["prevnodepoints"].values()[0]
				sname = "BlipSound"
			elif len(xcdata.get("newonepathpairs", [])) != 0:
				xcname = xcdata["newonepathpairs"][0]
			elif len(xcdata.get("prevonepathpairs", [])) != 0:
				xcname = xcdata["prevonepathpairs"][0]
			if xcname != null:
				var xcn = xcdrawing.get_node("XCnodes").get_node_or_null(xcname)
				if xcn != null:
					tpos = xcn.translation
			if tpos != null:
				Tglobal.soundsystem.quicksound(sname, xcdrawing.global_transform*tpos)

	for xcdrawing in xcdrawingstoupdate.values():
		xcdrawing.updatexcpaths()
	for xctube in xctubestoupdate.values():
		xctube.updatetubelinkpaths(self)
	#xctube0.updatetubeshell(sketchsystem.get_node("XCdrawings"), Tglobal.tubeshellsvisible)
	
remote func xcdrawingfromdata(xcdata):
	var xcdrawing = $XCdrawings.get_node_or_null(xcdata["name"])
	if xcdrawing == null:
		if xcdata["drawingtype"] == DRAWING_TYPE.DT_FLOORTEXTURE or xcdata["drawingtype"] == DRAWING_TYPE.DT_PAPERTEXTURE:
			xcdrawing = newXCuniquedrawingPaper(xcdata["xcresource"], xcdata["drawingtype"])
			assert (xcdrawing["name"] == xcdrawing.get_name())
		else:
			xcdrawing = newXCuniquedrawing(xcdata["drawingtype"], xcdata["name"])
	xcdrawing.mergexcrpcdata(xcdata)
	if xcdrawing.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE or xcdrawing.drawingtype == DRAWING_TYPE.DT_PAPERTEXTURE:
		get_node("/root/Spatial/ImageSystem").fetchpaperdrawing(xcdrawing)
	if xcdrawing.drawingtype == DRAWING_TYPE.DT_CENTRELINE:
		assert (false)   # shouldn't happen, not to be updated!
		get_node("/root/Spatial/LabelGenerator").makenodelabelstask(xcdrawing, true)
	return xcdrawing
	
remote func sketchsystemfromdict(sketchdatadict):
	get_node("/root/Spatial").clearallprocessactivityforreload()
	var xcdrawings_old = $XCdrawings
	xcdrawings_old.set_name("XCdrawings_old")
	for x in xcdrawings_old.get_children():
		x.queue_free()   # because it's not transitive (should file a ticket)
	xcdrawings_old.queue_free()
	var xcdrawings_new = Spatial.new()
	xcdrawings_new.set_name("XCdrawings")
	add_child(xcdrawings_new)
	var xctubes_old = $XCtubes
	xctubes_old.set_name("XCtubes_old")
	for x in xctubes_old.get_children():
		x.queue_free()
	xctubes_old.queue_free()
	var xctubes_new = Spatial.new()
	xctubes_new.set_name("XCtubes")
	add_child(xctubes_new)
	
	for xcdrawingData in sketchdatadict["xcdrawings"]:
		var xcdrawing = null
		if xcdrawingData["drawingtype"] == DRAWING_TYPE.DT_FLOORTEXTURE or xcdrawingData["drawingtype"] == DRAWING_TYPE.DT_PAPERTEXTURE:
			xcdrawing = newXCuniquedrawingPaper(xcdrawingData["xcresource"], xcdrawingData["drawingtype"])
			xcdrawing.mergexcrpcdata(xcdrawingData)
			get_node("/root/Spatial/ImageSystem").fetchpaperdrawing(xcdrawing)
		else:
			xcdrawing = newXCuniquedrawing(xcdrawingData["drawingtype"], xcdrawingData["name"])
			xcdrawing.xcresource = xcdrawingData["xcresource"]
			xcdrawing.get_node("XCdrawingplane").visible = false
			xcdrawing.get_node("XCdrawingplane/CollisionShape").disabled = true
			xcdrawing.mergexcrpcdata(xcdrawingData)
			if xcdrawing.drawingtype == DRAWING_TYPE.DT_CENTRELINE:
				get_node("/root/Spatial/LabelGenerator").makenodelabelstask(xcdrawing, true)
		assert (xcdrawing.get_name() == xcdrawingData["name"])
		
	for xctdata in sketchdatadict["xctubes"]:
		xctubefromdata(xctdata)
	updatecentrelinevisibility()
	changetubedxcsvizmode()
	updateworkingshell()
	
	if "playerMe" in sketchdatadict:
		var playerMe = get_node("/root/Spatial").playerMe if get_node("/root/Spatial").playerMe != null else get_node("/root/Spatial/Players/PlayerMe")
		if "headtrans" in sketchdatadict["playerMe"]:
			var playerlam = (playerMe.networkID%10000)/10000.0
			var headtrans = sketchdatadict["playerMe"]["headtrans"]
			var vecahead = Vector3(headtrans.basis.z.x, 0, headtrans.basis.z.z).normalized()
			if playerMe.networkID > 1: 
				headtrans = Transform(headtrans.basis.rotated(Vector3(0,1,0), deg2rad(180)), headtrans.origin - 3.5*vecahead + Vector3(vecahead.z, 0, -vecahead.x)*(playerlam-0.5)*2)
			#  Solve: headtrans = playerMe.global_transform * playerMe.get_node("HeadCam").transform 
			var backrelorigintrans = headtrans * playerMe.get_node("HeadCam").transform.inverse()
			var angvec = Vector2(playerMe.global_transform.basis.x.dot(backrelorigintrans.basis.x), playerMe.global_transform.basis.z.dot(backrelorigintrans.basis.x))
			var relang = angvec.angle()
			playerMe.global_transform = Transform(playerMe.global_transform.basis.rotated(Vector3(0,1,0), -relang), backrelorigintrans.origin)
		else:
			playerMe.global_transform = sketchdatadict["playerMe"]["transformpos"]
	
	print("lllloaded")

func loadsketchsystem(fname):
	var sketchdatafile = File.new()
	sketchdatafile.open(fname, File.READ)
	var sketchdatadict = sketchdatafile.get_var()
	sketchdatafile.close()
	if Tglobal.connectiontoserveractive:
		rpc("sketchsystemfromdict", sketchdatadict)
	sketchsystemfromdict(sketchdatadict)
			
func uniqueXCname():
	var largestxcdrawingnumber = 0
	for xcdrawing in get_node("XCdrawings").get_children():
		var xcname = xcdrawing.get_name()
		var ns = xcname.find_last("s")
		if ns != -1:
			largestxcdrawingnumber = max(largestxcdrawingnumber, int(xcname.right(ns + 1)))
	var sname = "s%d" % (largestxcdrawingnumber+1)
	return sname
	
func newXCuniquedrawing(drawingtype, sname):
	var xcdrawing = XCdrawing.instance()
	xcdrawing.drawingtype = drawingtype
	xcdrawing.set_name(sname)
	get_node("XCdrawings").add_child(xcdrawing)
	assert (sname == xcdrawing.get_name())
	if drawingtype == DRAWING_TYPE.DT_XCDRAWING:
		xcdrawing.add_to_group("gpnoncentrelinegeo")
		xcdrawing.linewidth = 0.05
	elif drawingtype == DRAWING_TYPE.DT_CENTRELINE:
		xcdrawing.add_to_group("gpcentrelinegeo")
		xcdrawing.linewidth = 0.035
	else:
		assert (false)
	return xcdrawing
	

func newXCuniquedrawingPaper(xcresource, drawingtype):
	var fname = get_node("/root/Spatial/ImageSystem").getshortimagename(xcresource, false)
	var sname = fname+","
	for i in range($XCdrawings.get_child_count()+1):
		sname = fname+","+String(i)
		if not $XCdrawings.has_node(sname):
			break
			
	var xcdrawing = XCdrawing.instance()
	xcdrawing.drawingtype = drawingtype
	xcdrawing.xcresource = xcresource
	xcdrawing.set_name(sname)
	$XCdrawings.add_child(xcdrawing)
	assert (sname == xcdrawing.get_name())
	
	xcdrawing.get_node("XCdrawingplane").collision_layer = CollisionLayer.CL_Environment | CollisionLayer.CL_PointerFloor if xcdrawing.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE else CollisionLayer.CL_Pointer

	xcdrawing.get_node("XCdrawingplane").visible = true
	xcdrawing.get_node("XCdrawingplane/CollisionShape").disabled = false
	var m = preload("res://surveyscans/scanimagefloor.material").duplicate()
	m.albedo_texture = ImageTexture.new() 
	xcdrawing.get_node("XCdrawingplane/CollisionShape/MeshInstance").set_surface_material(0, m)
	if xcdrawing.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE:
		xcdrawing.rotation_degrees = Vector3(-90, 0, 0)
		xcdrawing.get_node("XCdrawingplane").scale = Vector3(50, 50, 1)

	return xcdrawing

func newXCtube(xcdrawing0, xcdrawing1):
	assert ((xcdrawing0.drawingtype == DRAWING_TYPE.DT_XCDRAWING and xcdrawing1.drawingtype == DRAWING_TYPE.DT_XCDRAWING) or
			(xcdrawing0.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE and xcdrawing1.drawingtype == DRAWING_TYPE.DT_XCDRAWING) or
			(xcdrawing0.drawingtype == DRAWING_TYPE.DT_CENTRELINE and xcdrawing1.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE))

	var xctube = XCtube.instance()
	xctube.xcname0 = xcdrawing0.get_name()
	xctube.xcname1 = xcdrawing1.get_name()
	xctube.positioningtube = xcdrawing0.drawingtype != DRAWING_TYPE.DT_XCDRAWING or xcdrawing1.drawingtype != DRAWING_TYPE.DT_XCDRAWING
	xctube.set_name("XCtube_"+xctube.xcname0+"_"+xctube.xcname1)
	xcdrawing0.xctubesconn.append(xctube)
	xcdrawing1.xctubesconn.append(xctube)
	assert (not $XCtubes.has_node(xctube.get_name()))
	$XCtubes.add_child(xctube)
	xctube.add_to_group("gpnoncentrelinegeo")
	return xctube
	
func removeXCtube(xctube):
	var xcdrawing0 = $XCdrawings.get_node_or_null(xctube.xcname0)
	var xcdrawing1 = $XCdrawings.get_node_or_null(xctube.xcname1)
	if xcdrawing0 != null:
		var i = xcdrawing0.xctubesconn.find(xctube)
		if i != -1:
			xcdrawing0.xctubesconn.remove(i)
	if xcdrawing1 != null:
		var i = xcdrawing1.xctubesconn.find(xctube)
		if i != -1:
			xcdrawing1.xctubesconn.remove(i)
