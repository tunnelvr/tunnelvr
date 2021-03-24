extends Node

func finemeshpolygon_networked(polypoints, leng, xcdrawing):
	var playerwithexecutefeatures = null
	for player in get_node("/root/Spatial/Players").get_children():
		if player.executingfeaturesavailable.has("finemeshpolygon"):
			playerwithexecutefeatures = player
			break
	if playerwithexecutefeatures == null:
		print("no player able to execute finemeshpolygon")
		return
	elif playerwithexecutefeatures.networkID == get_node("/root/Spatial").playerMe.networkID:
		call_deferred("finemeshpolygon_execute", polypoints, 0.25, xcdrawing.get_name())
	else:
		rpc_id(playerwithexecutefeatures.networkID, "finemeshpolygon_execute", polypoints, 0.25, xcdrawing.get_name())
		print("rpc on finemeshpolygon_execute")
		

var pymeshpid = -1
remote func finemeshpolygon_execute(polypoints, leng, xcdrawingname):
	print("entering finemeshpolygon_execute")
	if pymeshpid != -1:
		print("already busy")
		return null
	
	var pi = Geometry.triangulate_polygon(polypoints)
	var vertices = [ ]
	for p in polypoints:
		vertices.push_back([p.x, p.y])
	var faces = [ ]
	for i in range(0, len(pi), 3):
		faces.push_back([pi[i], pi[i+1], pi[i+2]])
	
	var dir = Directory.new()
	if not dir.dir_exists("user://executingfeatures"):
		dir.make_dir("user://executingfeatures")
	var fpolyname = "user://executingfeatures/polygon.txt"
	var fmeshname = "user://executingfeatures/mesh.txt"
	var fout = File.new()
	if fout.file_exists(fmeshname):
		dir.remove(fmeshname)
	
	fout.open(fpolyname, File.WRITE)
	fout.store_line(to_json([vertices, faces]))
	fout.close()
	var dc = "run -it --rm -v %s:/data -v %s:/code pymesh/pymesh /code/polytriangulator.py /data/polygon.txt %f /data/mesh.txt" % \
		[ ProjectSettings.globalize_path("user://executingfeatures"), ProjectSettings.globalize_path("res://executingfeatures"), leng ]
	print(dc)
	pymeshpid = OS.execute("docker", PoolStringArray(dc.split(" ")), false)
	print(pymeshpid)
	if pymeshpid == -1:
		print("fail")
		return null
	
	for i in range(20):
		yield(get_tree().create_timer(1.0), "timeout")
		if fout.file_exists(fmeshname):
			break
		print("waiting on fine triangulation ", i)
	if not fout.file_exists(fmeshname):
		print("no file after 20 seconds, kill")
		OS.kill(pymeshpid)
		pymeshpid = -1
		return null
	
	fout.open(fmeshname, File.READ)
	var x = parse_json(fout.get_line())
	fout.close()
	print("triangulation received with %d points and %d faces" % [len(x[0]), len(x[1])/3])
	var nvertices = [ ]
	for v in x[0]:
		nvertices.push_back(Vector3(v[0], v[1], 0.0))

	#			var p = ropepointreprojectXYZ(uv, sketchsystem)

	var sketchsystem = get_node("/root/Spatial/SketchSystem")
	sketchsystem.actsketchchange([{"name":xcdrawingname, "wingmesh":{"vertices":nvertices, "triangles":x[1]}}])
	return null

const flattenerexecutingplatforms = {
	"julianlinuxlaptop":"6e6e2e697912445d86bb1b5b93996cfe",
	"nixosserver":"unknown"
}

func executingfeaturesavailable():
	var res = [ ]
	var osuniqueid = OS.get_unique_id()
	if flattenerexecutingplatforms.values().has(osuniqueid):
		 res.append("finemeshpolygon")
		 res.append("meshflattener")
	return res


