tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******

func _run():
	print("Hello from the Godot Editor!")
	#var k = get_scene().get_node("drawnfloor/MeshInstance").mesh
	var k = get_scene().get_node("MeshInstance")
	print(k)
	print(k.mesh.size)
	return
	var ma = k.mesh.get_mesh_arrays()
	#print(len(ma[ArrayMesh.ARRAY_VERTEX]), " VERTEX ", ma[ArrayMesh.ARRAY_VERTEX])
	#print(len(ma[ArrayMesh.ARRAY_NORMAL]), " NORMAL ", ma[ArrayMesh.ARRAY_NORMAL])
	#print(len(ma[ArrayMesh.ARRAY_TANGENT]), " tan ", ma[ArrayMesh.ARRAY_TANGENT])
	#print("col ", ma[ArrayMesh.ARRAY_COLOR])
	#print(len(ma[ArrayMesh.ARRAY_TEX_UV]), " UV ", ma[ArrayMesh.ARRAY_TEX_UV])
	#print("bone ", ma[ArrayMesh.ARRAY_BONES])
	#print(ma[ArrayMesh.ARRAY_WEIGHTS])
	#print(len(ma[ArrayMesh.ARRAY_INDEX]), " INDEX ", ma[ArrayMesh.ARRAY_INDEX])
	
	var a = ArrayMesh.new()
	a.add_surface_from_arrays(ArrayMesh.PRIMITIVE_TRIANGLES, k.mesh.get_mesh_arrays())
	var m = MeshDataTool.new()
	m.create_from_surface(a, 0)
	print(m)
	print(m.get_edge_count())
	print(m.get_edge_vertex(0, 0))
	print(m.get_edge_vertex(0, 1))
	print(m.get_face_count())
	print(m.get_face_edge(0, 0))
	print(m.get_face_edge(0, 1))
	print(m.get_face_edge(0, 2))
	print(m.get_face_vertex(0, 0))
	print(m.get_face_vertex(0, 1))
	print(m.get_face_vertex(0, 2))
	print(m.get_vertex_bones(0))
	print(m.get_vertex(0))
	print(m.get_vertex_normal(0))
	print(m.get_vertex_tangent(0))
	print(m.get_vertex_edges(2))
	print(m.get_vertex_faces(2))
	m.set_face_meta(0, "hi there")
	m.set_meta("ding", "dong")
	m.set_edge_meta(0, "hi there 2")
	m.set_vertex_meta(0, "hi there 3")
	m.set_vertex(0, Vector3(99.0,999.0,9998.0))
	m.get_incoming_connections()
	print(m.get_face_meta(1))
	print(m.get_face_meta(0))
	
	var hk = [8,4,-9,6,10]
	hk.sort_custom(self, "sortfunc")
	print(hk)
	print(m)
	m.commit_to_surface(a)
	#ResourceSaver.save("testsave.tres", a)
	#ResourceSaver.save("testsave.tres", m)
	#ResourceSaver.save()
	#	"testsave.tres", self)  
