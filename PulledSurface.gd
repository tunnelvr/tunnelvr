extends MeshInstance


# Declare member variables here. Examples:
# var a = 2
# var b = "text"



onready var meshInstance = self
var angle = 0

func _ready():
	var material = SpatialMaterial.new()
	material.albedo_color = Color(1.0, 0.0, 0.0, 1.0)
	createMesh(5, material)

var vpoints = [ ]
func newmeshpoint(v):
	vpoints.append(v)

	while len(vpoints) > 18:
		vpoints.remove(0)
	if len(vpoints) >= 3:
		var surfaceTool = SurfaceTool.new()
		surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)

		for i in range(2, len(vpoints)):
			surfaceTool.add_vertex(vpoints[i-2])
			surfaceTool.add_vertex(vpoints[i-1])
			surfaceTool.add_vertex(vpoints[i])
		surfaceTool.generate_normals()
		var mesh = surfaceTool.commit()
		meshInstance.mesh = mesh
		
		var col_shape = ConcavePolygonShape.new()
		col_shape.set_faces(mesh.get_faces())
		print("sssss", get_node("../CollisionShape").get_shape())
		get_node("../CollisionShape").set_shape(col_shape)

func createMesh(size, material):
	var surfaceTool = SurfaceTool.new()
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	#surfaceTool.add_normal(Vector3(    0,     0,  1))
	
	surfaceTool.add_vertex(Vector3(-size, -size,  0))
	surfaceTool.add_vertex(Vector3( size,  size,  0))
	surfaceTool.add_vertex(Vector3( size, -size,  0))
	surfaceTool.add_vertex(Vector3(-size, -size,  0))
	surfaceTool.add_vertex(Vector3(-size,  size,  size))
	surfaceTool.add_vertex(Vector3( size,  size,  size))
	surfaceTool.generate_normals()

	var mesh = surfaceTool.commit()
	meshInstance.mesh = mesh
	

	#meshInstance.set_material_override(material)

