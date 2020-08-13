tool
extends Spatial

const XCdrawing = preload("res://nodescenes/XCdrawing.tscn")
const XCtube = preload("res://nodescenes/XCtube.tscn")
enum DRAWING_TYPE { DT_XCDRAWING = 0, DT_FLOORTEXTURE = 1, DT_CENTRELINE = 2 }

# Called when the node enters the scene tree for the first time.
func _ready():
	$XCdrawings/floordrawing.setasfloortype("res://surveyscans/DukeStResurvey-drawnup-p3.jpg", true)
	$Centreline.floordrawing = $XCdrawings/floordrawing
	var centrelinedrawing = newXCuniquedrawing("centreline")
	var centrelinedatafile = File.new()
	var fname = "res://surveyscans/dukest1resurvey2009.json"
	centrelinedatafile.open(fname, File.READ)
	var centrelinedata = parse_json(centrelinedatafile.get_line())
	centrelinedrawing.importcentrelinedata(centrelinedata)
	#var xsectgps = centrelinedata.xsectgps

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
		if xcdrawing1.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE and xcdrawing0.drawingtype != DRAWING_TYPE.DT_CENTRELINE:
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
	var floordrawing = get_node("XCdrawings/floordrawing")
	tubeshellsvisible = makevisible
	for xctube in $XCtubes.get_children():
		if not xctube.positioningtube:
			xctube.updatetubeshell(get_node("XCdrawings"), makevisible)
	

# Quick saving and loading of shape.  It goes to 
# C:\Users\ViveOne\AppData\Roaming\Godot\app_userdata\digtunnel
func savesketchsystem():
	var fname = "user://savegame.save"
	var xcdrawingsData = [ ]
	for xcdrawing in $XCdrawings.get_children():
		xcdrawingsData.append(xcdrawing.exportxcdata())
	var xctubesData = [ ]
	for xctube in $XCtubes.get_children():
		xctubesData.append([xctube.xcname0, xctube.xcname1, xctube.xcdrawinglink])
	var drawnstationnodes = $Centreline/DrawnStationNodes.get_children()
	var drawnstationnodesData = [ ]	
	for i in range(len(drawnstationnodes)):
		var dsn = drawnstationnodes[i]
		drawnstationnodesData.append([dsn.stationname, dsn.global_transform.origin.x, dsn.global_transform.origin.y, dsn.global_transform.origin.z])
	var save_dict = { "xcdrawings":xcdrawingsData,
					  "xctubes":xctubesData,
					  "drawnstationnodes":drawnstationnodesData }
	var save_game = File.new()
	save_game.open(fname, File.WRITE)
	save_game.store_line(to_json(save_dict))
	save_game.close()
	print("sssssaved")

func loadsketchsystem():
	var fname = "user://savegame.save"
	var save_game = File.new()
	save_game.open(fname, File.READ)
	var save_dict = parse_json(save_game.get_line())

	var drawnstationnodesData = save_dict["drawnstationnodes"]
	var xcdrawingsData = save_dict["xcdrawings"]
	var xctubesData = save_dict["xctubes"]
	
	for drawnstationnode in $Centreline/DrawnStationNodes.get_children():
		drawnstationnode.free()
	for drawnstationnodeData in drawnstationnodesData:
		var drawnstationnode = $Centreline.newdrawnstationnode()
		drawnstationnode.stationname = drawnstationnodeData[0]
		drawnstationnode.global_transform.origin = Vector3(drawnstationnodeData[1], drawnstationnodeData[2], drawnstationnodeData[3])

	# then move the floor by the drawnstationnodes (it should be done auto when we make the nodes connected)
	
	# then do the xcdrawings
	for xcdrawing in $XCdrawings.get_children():
		xcdrawing.free()
	for i in range(len(xcdrawingsData)):
		var xcdrawingData = xcdrawingsData[i]
		#print("iiii", xcdrawingData)
		var xcdrawing = newXCuniquedrawing(xcdrawingData["name"])
		xcdrawing.importxcdata(xcdrawingData)
		xcdrawing.get_node("XCdrawingplane").visible = false
		xcdrawing.get_node("XCdrawingplane/CollisionShape").disabled = true
		if xcdrawing.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE:
			xcdrawing.setasfloortype(xcdrawingData["shapeimage"][2], false)
		get_node("XCdrawings").add_child(xcdrawing)

	$Centreline.floordrawing = $XCdrawings/floordrawing
	# should move each into position by its connections

	# then do the tubes
	for xctube in $XCtubes.get_children():
		xctube.free()
	for i in range(len(xctubesData)):
		var xctubeData = xctubesData[i]
		print(i, xctubeData)
		var xctube = newXCtube(get_node("XCdrawings").get_node(xctubeData[0]), get_node("XCdrawings").get_node(xctubeData[1]))
		
		xctube.xcdrawinglink = xctubeData[2]
		xctube.updatetubelinkpaths(self)
	
	save_game.close()
		
	print("lllloaded")
		
func newXCuniquedrawing(sname=null):
	if sname == null:
		var largestxcdrawingnumber = 0
		for xcdrawing in get_node("XCdrawings").get_children():
			largestxcdrawingnumber = max(largestxcdrawingnumber, int(xcdrawing.get_name()))
		sname = "s%d" % (largestxcdrawingnumber+1)
	var xcdrawing = XCdrawing.instance()
	xcdrawing.set_name(sname)
	get_node("XCdrawings").add_child(xcdrawing)
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
	
