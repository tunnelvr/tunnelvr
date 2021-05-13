extends MeshInstance


func pointmeshfromplyfile(st, plyname, maxNpoints):
	print("Loading pointmesh ", plyname, " N ", maxNpoints)
	var fin = File.new()
	fin.open(plyname, File.READ)
	while fin.get_line() != "end_header":
		print(fin.get_line())
	for i in range(maxNpoints):
		var v = fin.get_line().trim_suffix(" ").split(" ")
		if len(v) == 8:
			st.add_vertex(Vector3(float(v[0]), float(v[2]), float(v[1])))
		else:
			break
	fin.close()

func pointmeshfromcsvfile(st, csvname):
	print("Loading pointmesh ", csvname)
	var fin = File.new()
	fin.open(csvname, File.READ)
	var v = fin.get_csv_line()
	var n = 0
	while len(v) == 3:
		n += 1
		if (n%500) == 0:
			print("pause at ", n)
			#yield(get_tree().create_timer(0.05), "timeout")
			yield(get_tree(), "idle_frame")
		st.add_vertex(Vector3(float(v[0]), float(v[2]), float(v[1])))
		v = fin.get_csv_line()
	fin.close()
	
#func _ready():
func LoadPointMesh():
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_POINTS)

	var fcheck = File.new()
	var plyname = "res://surveyscans/pointscans/WSC 10cm WGS1984 - Cloud.ply"
	var csvname = "res://surveyscans/pointscans/smallcloud.csvn"
	if false and fcheck.file_exists(plyname):
		pointmeshfromplyfile(st, plyname, 200000)
	elif fcheck.file_exists(csvname):
		yield(pointmeshfromcsvfile(st, csvname), "completed")
	else:
		print("point cloud files not found")
		for i in range(400):
			st.add_vertex(Vector3(4,i*0.2,67))
		
	var pointsmesh = Mesh.new()
	st.commit(pointsmesh)
	var mat = mesh.surface_get_material(0)
	pointsmesh.surface_set_material(0, mat)
	mesh = pointsmesh

