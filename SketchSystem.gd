tool
extends Spatial

const XCdrawing = preload("res://nodescenes/XCdrawing.tscn")
const XCtube = preload("res://nodescenes/XCtube.tscn")

# Called when the node enters the scene tree for the first time.
func _ready():
	$floordrawing.floortype = true
	#$floordrawing.otxcdIndex = $floordrawing.get_name()
	$floordrawing/XCdrawingplane.scale = Vector3(50, 50, 1)
	$floordrawing/XCdrawingplane.collision_layer |= 2
	$floordrawing/XCdrawingplane/CollisionShape/MeshInstance.material_override = load("res://surveyscans/scanimagefloor.material")
	$Centreline.floordrawing = $floordrawing

const linewidth = 0.05
var tubeshellsvisible = false

func xcapplyonepath(xcn0, xcn1):
	var xcdrawing0 = xcn0.get_parent().get_parent()
	var xcdrawing1 = xcn1.get_parent().get_parent()
	var bgroundanchortype = false
	if xcn0 != xcn1 and xcn1.get_parent().get_parent().get_name() == "floordrawing":
		bgroundanchortype = true
					
	if xcdrawing0 == xcdrawing1:
		xcdrawing0.xcotapplyonepath(xcn0.otIndex, xcn1.otIndex)
		xcdrawing0.updatexcpaths()
		return
		
	if not bgroundanchortype and xcdrawing0.get_name() > xcdrawing1.get_name():
		var tt = xcn0
		xcn0 = xcn1
		xcn1 = tt
		xcdrawing0 = xcn0.get_parent().get_parent()
		xcdrawing1 = xcn1.get_parent().get_parent()
		
	var xcdrawing0otxcdIndex = xcdrawing0.get_name()
	var xcdrawing1otxcdIndex = xcdrawing1.get_name()
	assert (xcdrawing1otxcdIndex == xcdrawing1.get_name() if not bgroundanchortype else "floordrawing")
	
	var xctube = null
	for lxctube in $XCtubes.get_children():
		if lxctube.otxcdIndex0 == xcdrawing0otxcdIndex and lxctube.otxcdIndex1 == xcdrawing1otxcdIndex:
			xctube = lxctube
			break
	if xctube == null:
		xctube = XCtube.instance()
		xctube.get_node("XCtubeshell/CollisionShape").shape = ConcavePolygonShape.new()   # bug.  this fails to get cloned
		xctube.otxcdIndex0 = xcdrawing0otxcdIndex
		xctube.otxcdIndex1 = xcdrawing1otxcdIndex
		xctube.set_name("XCtube_"+xctube.otxcdIndex0+"_"+xctube.otxcdIndex1)
		xcdrawing0.xctubesconn.append(xctube)
		if xcdrawing1 != null:
			xcdrawing1.xctubesconn.append(xctube)
		$XCtubes.add_child(xctube)
	
	xctube.xctubeapplyonepath(xcn0, xcn1)


func updateworkingshell(makevisible):
	var floordrawing = get_node("floordrawing")
	tubeshellsvisible = makevisible
	for xctube in $XCtubes.get_children():
		if xctube.otxcdIndex1 != "floordrawing":
			xctube.updatetubeshell(floordrawing, makevisible)
		else:
			print("SSSkipping xctube to floor case")
	

# Quick saving and loading of shape.  It goes to 
# C:\Users\ViveOne\AppData\Roaming\Godot\app_userdata\digtunnel
func savesketchsystem():
	var fname = "user://savegame.save"
	var floordrawingData = $floordrawing.exportdata()
	var xcdrawingsData = [ ]
	for i in range($XCdrawings.get_child_count()):
		xcdrawingsData.append($XCdrawings.get_child(i).exportdata())
	var xctubesData = [ ]
	for i in range($XCtubes.get_child_count()):
		var xctube = $XCtubes.get_child(i)
		xctubesData.append([xctube.otxcdIndex0, xctube.otxcdIndex1, xctube.xcdrawinglink])
	var drawnstationnodes = $Centreline/DrawnStationNodes.get_children()
	var drawnstationnodesData = [ ]	
	for i in range(len(drawnstationnodes)):
		var dsn = drawnstationnodes[i]
		drawnstationnodesData.append([dsn.stationname, dsn.global_transform.origin.x, dsn.global_transform.origin.y, dsn.global_transform.origin.z])
	var save_dict = { "floordrawing":floordrawingData,
					  "xcdrawings":xcdrawingsData,
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
	var floordrawingData = save_dict["floordrawing"]
	
	
	for drawnstationnode in $Centreline/DrawnStationNodes.get_children():
		drawnstationnode.free()
	for drawnstationnodeData in drawnstationnodesData:
		var drawnstationnode = $Centreline.newdrawnstationnode()
		drawnstationnode.stationname = drawnstationnodeData[0]
		drawnstationnode.global_transform.origin = Vector3(drawnstationnodeData[1], drawnstationnodeData[2], drawnstationnodeData[3])

	$floordrawing.importdata(floordrawingData)
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
		get_node("XCdrawings").add_child(xcdrawing)

	# should move each into position by its connections

	# then do the tubes
	for xctube in $XCtubes.get_children():
		xctube.free()
	for i in range(len(xctubesData)):
		var xctubeData = xctubesData[i]
		var xctube = XCtube.instance()
		xctube.get_node("XCtubeshell/CollisionShape").shape = ConcavePolygonShape.new()   # bug.  this fails to get cloned
		xctube.otxcdIndex0 = xctubeData[0]
		xctube.otxcdIndex1 = xctubeData[1]
		xctube.set_name("XCtube_"+xctube.otxcdIndex0+"_"+xctube.otxcdIndex1)
		get_node("XCdrawings").get_node(xctube.otxcdIndex0).xctubesconn.append(xctube)
		if xctube.otxcdIndex1 != "floordrawing":
			get_node("XCdrawings").get_node(xctube.otxcdIndex1).xctubesconn.append(xctube)
		else:
			$floordrawing.xctubesconn.append(xctube)
		$XCtubes.add_child(xctube)
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
		sname = "s%04d" % (largestxcdrawingnumber+1)
	var xcdrawing = XCdrawing.instance()
	xcdrawing.set_name(sname)
	get_node("XCdrawings").add_child(xcdrawing)
	return xcdrawing

