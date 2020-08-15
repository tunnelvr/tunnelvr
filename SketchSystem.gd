tool
extends Spatial

const XCdrawing = preload("res://nodescenes/XCdrawing.tscn")
const XCtube = preload("res://nodescenes/XCtube.tscn")

# Called when the node enters the scene tree for the first time.
func _ready():
	loaddefaultsketchsystem()
	
const linewidth = 0.05
var tubeshellsvisible = false

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
	xctube.updatetubelinkpaths(self)

func updateworkingshell(makevisible):
	tubeshellsvisible = makevisible
	for xctube in $XCtubes.get_children():
		if not xctube.positioningtube:
			xctube.updatetubeshell(get_node("XCdrawings"), makevisible)
	

# Quick saving and loading of shape.  It goes to 
# C:\Users\ViveOne\AppData\Roaming\Godot\app_userdata\digtunnel
func sketchsystemtodict():
	var xcdrawingsData = [ ]
	for xcdrawing in $XCdrawings.get_children():
		xcdrawingsData.append(xcdrawing.exportxcdata())
	var xctubesData = [ ]
	for xctube in $XCtubes.get_children():
		xctubesData.append([xctube.xcname0, xctube.xcname1, xctube.xcdrawinglink])
	var save_dict = { "xcdrawings":xcdrawingsData,
					  "xctubes":xctubesData }
	return save_dict
	
func savesketchsystem():
	var save_dict = sketchsystemtodict()
	var fname = "user://savegame.save"
	var save_game = File.new()
	save_game.open(fname, File.WRITE)
	save_game.store_line(to_json(save_dict))
	save_game.close()
	print("sssssaved")

func clearsketchsystem():
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
	assert (floordrawing.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE)
	return floordrawing

func loaddefaultsketchsystem():
	#clearsketchsystem()   # relies on Spatial.playerMe, which has not been initialized
	var floordrawing = newXCuniquedrawing(DRAWING_TYPE.DT_FLOORTEXTURE, "paper_DukeStResurvey-drawnup-p3")
	#$XCdrawings/floordrawing.setasfloortype("res://surveyscans/DukeStResurvey-drawnup-p3.jpg", true)
	get_node("/root/Spatial/ImageSystem").fetchpaperdrawing(floordrawing)

	var centrelinedrawing = newXCuniquedrawing(DRAWING_TYPE.DT_CENTRELINE, "centreline")
	var centrelinedatafile = File.new()
	var fname = "res://surveyscans/dukest1resurvey2009.json"
	centrelinedatafile.open(fname, File.READ)
	var centrelinedata = parse_json(centrelinedatafile.get_line())
	centrelinedrawing.importcentrelinedata(centrelinedata)
	#var xsectgps = centrelinedata.xsectgps
	print("default lllloaded")

remote func xcdrawingfromdict(xcdrawingData):
	var xcdrawing = $XCdrawings.get_node(xcdrawingData["name"])
	if xcdrawing == null:
		xcdrawing = newXCuniquedrawing(xcdrawingData.drawingtype, xcdrawingData["name"])
	xcdrawing.importxcdata(xcdrawingData)
	if xcdrawing.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE or xcdrawing.drawingtype == DRAWING_TYPE.DT_PAPERTEXTURE:
		get_node("/root/Spatial/ImageSystem").fetchpaperdrawing(xcdrawing)

remotesync func sketchsystemfromdict(save_dict):
	clearsketchsystem()
	var xcdrawingsData = save_dict["xcdrawings"]
	var xctubesData = save_dict["xctubes"]
	
	for i in range(len(xcdrawingsData)):
		var xcdrawingData = xcdrawingsData[i]
		#print("iiii", xcdrawingData)
		var xcdrawing = newXCuniquedrawing(xcdrawingData.drawingtype, xcdrawingData["name"])
		xcdrawing.importxcdata(xcdrawingData)
		if xcdrawing.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE or xcdrawing.drawingtype == DRAWING_TYPE.DT_PAPERTEXTURE:
			get_node("/root/Spatial/ImageSystem").fetchpaperdrawing(xcdrawing)
		else:
			xcdrawing.get_node("XCdrawingplane").visible = false
			xcdrawing.get_node("XCdrawingplane/CollisionShape").disabled = true
			
	for i in range(len(xctubesData)):
		var xctubeData = xctubesData[i]
		print(i, xctubeData)
		var xctube = newXCtube(get_node("XCdrawings").get_node(xctubeData[0]), get_node("XCdrawings").get_node(xctubeData[1]))
		xctube.xcdrawinglink = xctubeData[2]
		xctube.updatetubelinkpaths(self)
	
	print("lllloaded")

func loadsketchsystem():
	var fname = "user://savegame.save"
	var save_game = File.new()
	save_game.open(fname, File.READ)
	var save_dict = parse_json(save_game.get_line())
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

	if xcdrawing.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE:
		xcdrawing.get_node("XCdrawingplane").collision_layer |= CollisionLayer.CL_Environment
		xcdrawing.get_node("XCdrawingplane").visible = true
		xcdrawing.get_node("XCdrawingplane/CollisionShape").disabled = false
		var m = preload("res://surveyscans/scanimagefloor.material").duplicate()
		m.albedo_texture = ImageTexture.new() 
		xcdrawing.get_node("XCdrawingplane/CollisionShape/MeshInstance").set_surface_material(0, m)
		xcdrawing.rotation_degrees = Vector3(-90, 0, 0)
		xcdrawing.get_node("XCdrawingplane").scale = Vector3(50, 50, 1)
		
	elif xcdrawing.drawingtype == DRAWING_TYPE.DT_PAPERTEXTURE:
		xcdrawing.get_node("XCdrawingplane").collision_layer |= CollisionLayer.CL_Environment
		xcdrawing.get_node("XCdrawingplane").visible = true
		xcdrawing.get_node("XCdrawingplane/CollisionShape").disabled = false
		var m = preload("res://surveyscans/scanimagefloor.material").duplicate()
		m.albedo_texture = ImageTexture.new() 
		xcdrawing.get_node("XCdrawingplane/CollisionShape/MeshInstance").set_surface_material(0, m)

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
	return xctube
	
