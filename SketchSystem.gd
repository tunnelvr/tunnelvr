tool
extends Spatial

onready var ot = load("res://OneTunnel.gd").new()

# Called when the node enters the scene tree for the first time.
func _ready():
	print("oooooo", ot)
	
const OnePathNode = preload("res://nodescenes/OnePathNode.tscn")
const linewidth = 0.05

func newonepathnode(lotIndex):
	var opn = OnePathNode.instance()
	$OnePathNodes.add_child(opn)
	if lotIndex == -1:
		opn.otIndex = ot.newotnodepoint()
	else:
		opn.otIndex = lotIndex
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

func updateonepaths():
	print("iupdatingpaths ", len(ot.onepathpairs))
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
	print("usus ", len($PathLines.mesh.get_faces()), " ", len($PathLines.mesh.get_faces())) #surfaceTool.generate_normals()
	#updateworkingshell()

func updateworkingshell(makevisible):
	if makevisible:
		$WorkingShell/MeshInstance.mesh = ot.makeworkingshell()
		$WorkingShell/CollisionShape.shape.set_faces($WorkingShell/MeshInstance.mesh.get_faces())
		$WorkingShell.visible = true
		$WorkingShell/CollisionShape.disabled = false
	else:
		$WorkingShell.visible = false
		$WorkingShell/CollisionShape.disabled = true
	

# Quick saving and loading of shape.  It goes to 
# C:\Users\ViveOne\AppData\Roaming\Godot\app_userdata\digtunnel
# We could check if we can export mesh things this way
func savesketchsystem():
	assert (ot.verifyonetunnelmatches(self))
	var drawnstationnodes = get_node("Centreline/DrawnStationNodes").get_children()
	ot.drawnstationnodesRAW.clear()	
	for i in range(len(drawnstationnodes)):
		var dsn = drawnstationnodes[i]
		ot.drawnstationnodesRAW.append([dsn.global_transform.origin.x, dsn.global_transform.origin.y, dsn.global_transform.origin.z, dsn.drawingname, dsn.uvpoint.x, dsn.uvpoint.y, dsn.stationname])
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
		dsn.drawingname = ndsn[3]
		dsn.uvpoint.x = ndsn[4]
		dsn.uvpoint.y = ndsn[5]
		dsn.stationname = ndsn[6]
	drawnstationnodes = get_node("Centreline/DrawnStationNodes").get_children()
	for i in range(len(ot.drawnstationnodesRAW), len(drawnstationnodes)):
		drawnstationnodes[i].queue_free()
		
	print("lllloaded")
		


