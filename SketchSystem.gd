tool
extends Spatial

onready var ot = load("res://OneTunnel.gd").new()

# Called when the node enters the scene tree for the first time.
func _ready():
	$floordrawing.floortype = true
	$floordrawing/XCdrawingplane.scale = Vector3(50, 50, 1)
	$floordrawing/XCdrawingplane.collision_layer |= 2
	print("mmmm ", load("res://surveyscans/scanimagefloor.material"))
	
	$floordrawing/XCdrawingplane/CollisionShape/MeshInstance.material_override = load("res://surveyscans/scanimagefloor.material")
	
	
const OnePathNode = preload("res://nodescenes/OnePathNode.tscn")
const XCtube = preload("res://nodescenes/XCtube.tscn")

const linewidth = 0.05

func newonepathnode(lotIndex):
	var opn = OnePathNode.instance()
	$OnePathNodes.add_child(opn)
	if lotIndex == -1:
		opn.otIndex = ot.newotnodepoint()
	else:
		opn.otIndex = lotIndex
	opn.set_name("OnePathNode"+String(opn.otIndex))  # We could use to_int on this to abolish need for otIndex
	return opn

func removeonepathnode(opn):
	if ot.removeotnodepoint(opn.otIndex):
		ot.copyotnodetoopn($OnePathNodes.get_child(opn.otIndex))
	$OnePathNodes.get_child($OnePathNodes.get_child_count()-1).free()
	updateonepaths()
	assert (ot.verifyonetunnelmatches(self))

func applyonepath(opn0, opn1):
	ot.applyonepath(opn0.otIndex, opn1.otIndex)
	updateonepaths()
	assert (ot.verifyonetunnelmatches(self))

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
		
	if not bgroundanchortype and xcdrawing0.otxcdIndex > xcdrawing1.otxcdIndex:
		var tt = xcn0
		xcn0 = xcn1
		xcn1 = tt
		xcdrawing0 = xcn0.get_parent().get_parent()
		xcdrawing1 = xcn1.get_parent().get_parent()
		
	var xcdrawing0otxcdIndex = xcdrawing0.otxcdIndex
	var xcdrawing1otxcdIndex = xcdrawing1.otxcdIndex if not bgroundanchortype else -1

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
		xctube.set_name("XCtube"+String(xcdrawing0otxcdIndex)+"_"+String(xcdrawing1otxcdIndex))
		xcdrawing0.xctubesconn.append(xctube)
		if xcdrawing1 != null:
			xcdrawing1.xctubesconn.append(xctube)
		$XCtubes.add_child(xctube)
	
	xctube.xctubeapplyonepath(xcn0, xcn1)

func updateonepaths():
	var surfaceTool = SurfaceTool.new()
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in range(0, len(ot.onepathpairs), 2):
		var p0 = ot.nodepoints[ot.onepathpairs[j]] + Vector3(0, 0.005, 0)
		var p1 = ot.nodepoints[ot.onepathpairs[j+1]] + Vector3(0, 0.005, 0)
		var perp = linewidth*Vector2(-(p1.z - p0.z), p1.x - p0.x).normalized()
		var p0left = p0 - Vector3(perp.x, 0, perp.y)
		var p0right = p0 + Vector3(perp.x, 0, perp.y)
		var p1left = p1 - Vector3(perp.x, 0, perp.y)
		var p1right = p1 + Vector3(perp.x, 0, perp.y)
		surfaceTool.add_vertex(p0left)
		surfaceTool.add_vertex(p1left)
		surfaceTool.add_vertex(p0right)
		surfaceTool.add_vertex(p0right)
		surfaceTool.add_vertex(p1left)
		surfaceTool.add_vertex(p1right)
	surfaceTool.generate_normals()
	$PathLines.mesh = surfaceTool.commit()
	#updateworkingshell()

func updateworkingshell(makevisible):
	var floordrawing = get_node("floordrawing")
	for xctube in $XCtubes.get_children():
		if xctube.otxcdIndex1 != -1:
			xctube.updatetubeshell(floordrawing, makevisible)
		else:
			print("SSSkipping xctube to floor case")
	

# Quick saving and loading of shape.  It goes to 
# C:\Users\ViveOne\AppData\Roaming\Godot\app_userdata\digtunnel
# We could check if we can export mesh things this way
func savesketchsystem():
	assert (ot.verifyonetunnelmatches(self))
	var drawnstationnodes = get_node("Centreline/DrawnStationNodes").get_children()
	ot.drawnstationnodesRAW.clear()	
	for i in range(len(drawnstationnodes)):
		var dsn = drawnstationnodes[i]
		ot.drawnstationnodesRAW.append([dsn.global_transform.origin.x, dsn.global_transform.origin.y, dsn.global_transform.origin.z, dsn.stationname])
	ot.saveonetunnel("user://savegame.save")
	print("sssssaved")

func loadsketchsystem():
	ot.loadonetunnel("user://savegame.save")
	var onepathnodes = get_node("OnePathNodes").get_children()
	for i in range(len(onepathnodes)):
		onepathnodes[i].free()
	print("sdfsdf", get_node("OnePathNodes").get_child_count())
	assert (get_node("OnePathNodes").get_child_count() == 0)
	
	for i in range(len(ot.nodepoints)):
		var opn = newonepathnode(i)
		ot.copyotnodetoopn(opn)
				
	onepathnodes = get_node("OnePathNodes").get_children()
	assert (len(ot.nodepoints) == len(onepathnodes))
	updateonepaths()
		
	var drawnstationnodes = get_node("Centreline/DrawnStationNodes").get_children()
	for i in range(len(ot.drawnstationnodesRAW)):
		var dsn = (drawnstationnodes[i]  if i < len(drawnstationnodes)  else get_node("Centreline").newdrawnstationnode())
		var ndsn = ot.drawnstationnodesRAW[i]
		dsn.global_transform.origin.x = ndsn[0]
		dsn.global_transform.origin.y = ndsn[1]
		dsn.global_transform.origin.z = ndsn[2]
		dsn.stationname = ndsn[3]
	drawnstationnodes = get_node("Centreline/DrawnStationNodes").get_children()
	for i in range(len(ot.drawnstationnodesRAW), len(drawnstationnodes)):
		drawnstationnodes[i].queue_free()
		
	print("lllloaded")
		


