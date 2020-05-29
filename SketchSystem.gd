tool
extends Spatial

# Called when the node enters the scene tree for the first time.
func _ready():
	updateworkingshell()
	updateworkingshell()
const OnePathNode = preload("res://OnePathNode.tscn")
const linewidth = 0.05

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

