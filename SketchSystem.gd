extends Spatial

const XCdrawing = preload("res://nodescenes/XCdrawing.tscn")
const XCtube = preload("res://nodescenes/XCtube.tscn")

const linewidth = 0.05
var tubeshellsvisible = false
var centrelineonlymode = false
const defaultfloordrawing = "http://cave-registry.org.uk/svn/NorthernEngland/ThreeCountiesArea/rawscans/Ireby/DukeStResurvey-drawnup-p3.jpg"

func _ready():
	var floordrawing = newXCuniquedrawingPaper(defaultfloordrawing, DRAWING_TYPE.DT_FLOORTEXTURE)
	get_node("/root/Spatial/ImageSystem").fetchpaperdrawing(floordrawing)

	#loadcentrelinefile("res://surveyscans/dukest1resurvey2009.json")
	#loadcentrelinefile("res://surveyscans/dukest1resurvey2009json.res")
	loadcentrelinefile("res://surveyscans/Ireby/Ireby2/Ireby2.json")
	
func xcapplyonepath(xcn0, xcn1): 
	var xcdrawing0 = xcn0.get_parent().get_parent()
	var xcdrawing1 = xcn1.get_parent().get_parent()
					
	if xcdrawing0 == xcdrawing1:
		xcdrawing0.xcotapplyonepath(xcn0.get_name(), xcn1.get_name())
		xcdrawing0.updatexcpaths()
		return
		
	var xctube = null
	var xctubeRev = null
	for lxctube in xcdrawing0.xctubesconn:
		assert (lxctube.xcname0 == xcdrawing0.get_name() or lxctube.xcname1 == xcdrawing0.get_name())
		if lxctube.xcname1 == xcdrawing1.get_name():
			xctube = lxctube
			break
		if lxctube.xcname0 == xcdrawing1.get_name():
			xctubeRev = lxctube
			break

	if xctube == null and xctubeRev == null:
		if xcdrawing0.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE and xcdrawing1.drawingtype == DRAWING_TYPE.DT_CENTRELINE:
			xctubeRev = newXCtube(xcdrawing1, xcdrawing0)
		elif xcdrawing0.drawingtype == DRAWING_TYPE.DT_XCDRAWING and xcdrawing1.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE:
			xctubeRev = newXCtube(xcdrawing1, xcdrawing0)
		else:
			xctube = newXCtube(xcdrawing0, xcdrawing1)
	if xctube != null:
		xctube.xctubeapplyonepath(xcn0, xcn1)
	else:
		xctubeRev.xctubeapplyonepath(xcn1, xcn0)
		xctube = xctubeRev
		
	if xctube.positioningtube:
		xctube.positionfromtubelinkpaths(self)
		rpc("xcdrawingfromdata", xcdrawing1.exportxcrpcdata())
	xctube.updatetubelinkpaths(self)
	rpc("xctubefromdata", xctube.exportxctrpcdata())

remote func xctubefromdata(xctdata):
	# exportxctrpcdata():  return [ get_name(), xcname0, xcname1, xcdrawinglink ]
	var xcdrawing0 = get_node("XCdrawings").get_node(xctdata["xcname0"])
	var xctube = null
	for lxctube in xcdrawing0.xctubesconn:
		if lxctube.xcname1 == xctdata["xcname1"]:
			assert (lxctube.xcname0 == xctdata["xcname0"])
			xctube = lxctube
			break
		assert (lxctube.xcname0 != xctdata["xcname1"])
	if xctube == null:
		assert ($XCtubes.get_node(xctdata["name"]) == null)
		xctube = newXCtube(xcdrawing0, get_node("XCdrawings").get_node(xctdata["xcname1"]))
	assert (xctube.get_name() == xctdata["name"])
	xctube.xcdrawinglink = xctdata["xcdrawinglink"]
	xctube.xcsectormaterials = xctdata["xcsectormaterials"]
	xctube.updatetubelinkpaths(self)

remotesync func updateworkingshell(makevisible):
	tubeshellsvisible = makevisible
	for xctube in $XCtubes.get_children():
		if not xctube.positioningtube:
			xctube.updatetubeshell($XCdrawings, makevisible)
	for xcdrawing in $XCdrawings.get_children():
		if xcdrawing.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
			xcdrawing.updatexctubeshell($XCdrawings, makevisible)

remotesync func changecentrelineonlymode(lcentrelineonlymode):
	centrelineonlymode = lcentrelineonlymode
	get_tree().call_group("gpnoncentrelinegeo", "xcdfullsetvisibilitycollision", not centrelineonlymode)
	get_node("/root/Spatial/PlanViewSystem").updatecentrelinesizes()

# Quick saving and loading of shape.  It goes to 
# C:\Users\ViveOne\AppData\Roaming\Godot\app_userdata\digtunnel
func sketchsystemtodict():
	var xcdrawingsData = [ ]
	for xcdrawing in $XCdrawings.get_children():
		xcdrawingsData.append(xcdrawing.exportxcrpcdata())
	var xctubesData = [ ]
	for xctube in $XCtubes.get_children():
		xctubesData.append(xctube.exportxctrpcdata())
	var save_dict = { "xcdrawings":xcdrawingsData,
					  "xctubes":xctubesData }
	return save_dict
	
func savesketchsystem():
	var save_dict = sketchsystemtodict()
	var fname = "user://savegame.save"
	var save_game = File.new()
	save_game.open(fname, File.WRITE)
	#save_game.store_line(to_json(save_dict))
	save_game.store_var(save_dict)
	save_game.close()
	print("sssssaved")

func clearsketchsystem():
	get_node("/root/Spatial/LabelGenerator").clearlabellingprocess()
	var pointersystem = get_node("/root/Spatial").playerMe.get_node("pointersystem")
	pointersystem.setselectedtarget(null)  # clear all the objects before they are freed
	pointersystem.pointertarget = null
	pointersystem.pointertargettype = "none"
	pointersystem.pointertargetwall = null
	pointersystem.activetargetwall = null
	pointersystem.activetargetwallgrabbedtransform = null
	for xcdrawing in $XCdrawings.get_children():
		xcdrawing.free()
	for xctube in $XCtubes.get_children():
		xctube.free()

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
	get_node("/root/Spatial/LabelGenerator").makenodelabelstask(centrelinedrawing)
	print("default lllloaded")

remote func xcdrawingfromdata(xcdata):
	var xcdrawing = $XCdrawings.get_node(xcdata["name"])
	if xcdrawing == null:
		if xcdata["drawingtype"] == DRAWING_TYPE.DT_FLOORTEXTURE or xcdata["drawingtype"].drawingtype == DRAWING_TYPE.DT_PAPERTEXTURE:
			xcdrawing = newXCuniquedrawingPaper(xcdata["xcresource"], xcdata["drawingtype"])
			assert (xcdrawing["name"] == xcdrawing.get_name())
		else:
			xcdrawing = newXCuniquedrawing(xcdata["drawingtype"], xcdata["name"])
	xcdrawing.mergexcrpcdata(xcdata)
	if xcdrawing.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE or xcdrawing.drawingtype == DRAWING_TYPE.DT_PAPERTEXTURE:
		get_node("/root/Spatial/ImageSystem").fetchpaperdrawing(xcdrawing)
	if xcdrawing.drawingtype == DRAWING_TYPE.DT_CENTRELINE:
		get_node("/root/Spatial/LabelGenerator").makenodelabelstask(xcdrawing)
	
remotesync func sketchsystemfromdict(save_dict):
	clearsketchsystem()
	var xcdrawingsData = save_dict["xcdrawings"]
	var xctubesData = save_dict["xctubes"]
	
	for i in range(len(xcdrawingsData)):
		var xcdrawingData = xcdrawingsData[i]
		#print("iiii", xcdrawingData)
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
				get_node("/root/Spatial/LabelGenerator").makenodelabelstask(xcdrawing)
		assert (xcdrawing.get_name() == xcdrawingData["name"])

	for i in range(len(xctubesData)):
		var xctube = xctubefromdata(xctubesData[i])
	print("lllloaded")

func loadsketchsystem():
	var fname = "user://savegame.save"
	var save_game = File.new()
	save_game.open(fname, File.READ)
	#var save_dict = parse_json(save_game.get_line())
	var save_dict = save_game.get_var()
	save_game.close()
	rpc("sketchsystemfromdict", save_dict)

func uniqueXCname():
	var largestxcdrawingnumber = 0
	for xcdrawing in get_node("XCdrawings").get_children():
		largestxcdrawingnumber = max(largestxcdrawingnumber, int(xcdrawing.get_name()))
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
	
