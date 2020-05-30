tool
extends Spatial

# Called when the node enters the scene tree for the first time.
func _ready():
	updateworkingshell()
const OnePathNode = preload("res://OnePathNode.tscn")
const linewidth = 0.05

var onepathpairs = [ ]  # pairs of onepath nodes

func newonepathnode(point):
	var opn = OnePathNode.instance()
	$OnePathNodes.add_child(opn)
	opn.scale.y = 0.2
	opn.global_transform.origin = point
	return opn

func removeonepathnode(opn):
	print("to remove node ", opn)
	for i in range(len(onepathpairs)-1, -1, -1):
		if onepathpairs[i][0] == opn or onepathpairs[i][1] == opn:
			onepathpairs.remove(i)
			print("deletedonepath ", i)
	$OnePathNodes.remove_child(opn)
	updateonepaths()

func applyonepath(opn0, opn1):
	for i in range(len(onepathpairs)-1, -2, -1):
		if i == -1:
			print("addingonepath ", len(onepathpairs))
			onepathpairs.append([opn0, opn1])
		elif (onepathpairs[i][0] == opn0 and onepathpairs[i][1] == opn1) or (onepathpairs[i][0] == opn1 and onepathpairs[i][1] == opn0):
			onepathpairs.remove(i)
			print("deletedonepath ", i)
			break
	updateonepaths()

func updateonepaths():
	print("iupdatingpaths ", len(onepathpairs))
	var surfaceTool = SurfaceTool.new()
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for onepath in onepathpairs:
		var p0 = onepath[0].global_transform.origin + Vector3(0, onepath[0].scale.y+0.005, 0)
		var p1 = onepath[1].global_transform.origin + Vector3(0, onepath[1].scale.y+0.005, 0)
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
	$WorkingShell.mesh = surfaceTool.commit()
	print("usus ", len($WorkingShell.mesh.get_faces()), " ", len($WorkingShell.mesh.get_faces())) #surfaceTool.generate_normals()


func updateworkingshell():
	var cverts = PoolVector3Array()
	
	for opn in $OnePathNodes.get_children():
		cverts.push_back(opn.global_transform.origin + Vector3(0, opn.scale.y, 0))
	if len(cverts) < 2:
		cverts.push_back(Vector3(0, 0.1, -3))
		cverts.push_back(Vector3(1, 0.1, -3))
		cverts.push_back(Vector3(2, 0.1, -4))

	var surfaceTool = SurfaceTool.new()
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var p0left
	var p0right; 
	for i in range(len(cverts)):
		var i1 = max(1, i)
		var perp = linewidth*Vector2(-(cverts[i1].z - cverts[i1-1].z), cverts[i1].x - cverts[i1-1].x).normalized()
		var p1left = cverts[i] - Vector3(perp.x, 0, perp.y)
		var p1right = cverts[i] + Vector3(perp.x, 0, perp.y)
		if i != 0:
			surfaceTool.add_vertex(p0left)
			surfaceTool.add_vertex(p1left)
			surfaceTool.add_vertex(p0right)
			surfaceTool.add_vertex(p0right)
			surfaceTool.add_vertex(p1left)
			surfaceTool.add_vertex(p1right)
		p0left = p1left
		p0right = p1right
	surfaceTool.generate_normals()
	$WorkingShell.mesh = surfaceTool.commit()
	print("usus ", len($WorkingShell.mesh.get_faces()), " ", len($WorkingShell.mesh.get_faces())) #surfaceTool.generate_normals()


	#meshInstance.set_material_override(material)

