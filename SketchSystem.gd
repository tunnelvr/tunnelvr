tool
extends Spatial

const XCdrawing = preload("res://nodescenes/XCdrawing.tscn")
const XCtube = preload("res://nodescenes/XCtube.tscn")

# Called when the node enters the scene tree for the first time.
func _ready():
	$XCdrawings/floordrawing.setasfloortype()
	$Centreline.floordrawing = $XCdrawings/floordrawing

const linewidth = 0.05
var tubeshellsvisible = false

func xcapplyonepath(xcn0, xcn1):
	var xcdrawing0 = xcn0.get_parent().get_parent()
	var xcdrawing1 = xcn1.get_parent().get_parent()
					
	if xcdrawing0 == xcdrawing1:
		xcdrawing0.xcotapplyonepath(xcn0.otIndex, xcn1.otIndex)
		xcdrawing0.updatexcpaths()
		return
		
	var xctube = null
	var xctubeRev = null
	for lxctube in $XCtubes.get_children():
		if lxctube.xcname0 == xcdrawing0.get_name() and lxctube.xcname1 == xcdrawing1.get_name():
			xctube = lxctube
			break
		if lxctube.xcname0 == xcdrawing1.get_name() and lxctube.xcname1 == xcdrawing0.get_name():
			xctubeRev = lxctube
			break
	if xctube != null:
		xctube.xctubeapplyonepath(xcn0, xcn1)
	elif xctubeRev != null:
		xctubeRev.xctubeapplyonepath(xcn1, xcn0)
		xctube = xctubeRev
	else:
		xctube = newXCtube(xcdrawing0, xcdrawing1)
		xctube.xctubeapplyonepath(xcn0, xcn1)
	var xcdrawings = xcn0.get_parent().get_parent().get_parent()
	var sketchsystem = xcdrawings.get_parent()
	xctube.updatetubelinkpaths(xcdrawings, sketchsystem)

func updateworkingshell(makevisible):
	var floordrawing = get_node("XCdrawings/floordrawing")
	tubeshellsvisible = makevisible
	for xctube in $XCtubes.get_children():
		if (not get_node("XCdrawings").get_node(xctube.xcname0).floortype) and (not get_node("XCdrawings").get_node(xctube.xcname1).floortype):
			xctube.updatetubeshell(floordrawing, makevisible)
		else:
			print("SSSkipping xctube to floor case")
	

# Quick saving and loading of shape.  It goes to 
# C:\Users\ViveOne\AppData\Roaming\Godot\app_userdata\digtunnel
func savesketchsystem():
	var fname = "user://savegame.save"
	var xcdrawingsData = [ ]
	for i in range($XCdrawings.get_child_count()):
		xcdrawingsData.append($XCdrawings.get_child(i).exportdata())
	var xctubesData = [ ]
	for i in range($XCtubes.get_child_count()):
		var xctube = $XCtubes.get_child(i)
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
		print("iiii", xcdrawingData)
		var xcdrawing = newXCuniquedrawing(xcdrawingData["name"])
		xcdrawing.importdata(xcdrawingData)
		xcdrawing.get_node("XCdrawingplane").visible = false
		xcdrawing.get_node("XCdrawingplane/CollisionShape").disabled = true
		if xcdrawing.floortype:
			xcdrawing.setasfloortype()
		get_node("XCdrawings").add_child(xcdrawing)

	$Centreline.floordrawing = $XCdrawings/floordrawing
	# should move each into position by its connections

	# then do the tubes
	for xctube in $XCtubes.get_children():
		xctube.free()
	for i in range(len(xctubesData)):
		var xctubeData = xctubesData[i]
		var xctube = newXCtube(get_node("XCdrawings").get_node(xctubeData[0]), get_node("XCdrawings").get_node(xctubeData[1]))
		
		xctube.xcdrawinglink = xctubeData[2]
		for j in range(len(xctube.xcdrawinglink)):
			xctube.xcdrawinglink[j] = int(xctube.xcdrawinglink[j])
		xctube.updatetubelinkpaths($XCdrawings, self)
	
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
	var xctube = XCtube.instance()
	xctube.xcname0 = xcdrawing0.get_name()
	xctube.xcname1 = xcdrawing1.get_name()
	xctube.set_name("XCtube_"+xctube.xcname0+"_"+xctube.xcname1)
	xcdrawing0.xctubesconn.append(xctube)
	xcdrawing1.xctubesconn.append(xctube)
	$XCtubes.add_child(xctube)
	return xctube
	
