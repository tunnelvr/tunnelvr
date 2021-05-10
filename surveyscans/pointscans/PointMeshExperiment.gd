extends MeshInstance


# Called when the node enters the scene tree for the first time.

func _ready():
	var plyname = "res://surveyscans/pointscans/WSC 10cm WGS1984 - Cloud.ply"
	var mat = mesh.surface_get_material(0)
	var pointsmesh = Mesh.new()
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_POINTS)
	var fout = File.new()
	if fout.file_exists(plyname):
		fout.open(plyname, File.READ)
		while fout.get_line() != "end_header":
			print(fout.get_line())
		print("-----------------points")
		for i in range(300000):
			var v = fout.get_line().trim_suffix(" ").split(" ")
			if len(v) == 8:
				st.add_vertex(Vector3(float(v[0]), float(v[2]), float(v[1])))
			else:
				break
		fout.close()
	else:
		for i in range(200):
			st.add_vertex(Vector3(0,i*0.2,0))
	st.commit(pointsmesh)
	mesh = pointsmesh
	mesh.surface_set_material(0, mat)

