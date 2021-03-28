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
		call_deferred("finemeshpolygon_execute", polypoints, 0.125, xcdrawing.get_name())
	else:
		rpc_id(playerwithexecutefeatures.networkID, "finemeshpolygon_execute", polypoints, 0.25, xcdrawing.get_name())
		print("rpc on finemeshpolygon_execute")
		

var pymeshpid = -1
remote func finemeshpolygon_execute(polypoints, leng, xcdrawingname):
	print("entering finemeshpolygon_execute")
	if pymeshpid != -1:
		print("already busy")
		return

	var sketchsystem = get_node("/root/Spatial/SketchSystem")
	var xcdrawingf = sketchsystem.get_node("XCdrawings").get_node(xcdrawingname)
	var xcropedrawingwing = null
	if len(xcdrawingf.xctubesconn) == 1:
		var xctube = xcdrawingf.xctubesconn[0]
		var xcropedrawingwingname = (xctube.xcname1 if xctube.xcname0 == xcdrawingname else xctube.xcname0)
		xcropedrawingwing = sketchsystem.get_node("XCdrawings").get_node(xcropedrawingwingname)
		assert (xcropedrawingwing.drawingtype == DRAWING_TYPE.DT_ROPEHANG)

	
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
		return
	
	for i in range(20):
		yield(get_tree().create_timer(1.0), "timeout")
		if fout.file_exists(fmeshname):
			break
		print("waiting on fine triangulation ", i)
	if not fout.file_exists(fmeshname):
		print("no file after 20 seconds, kill")
		OS.kill(pymeshpid)
		pymeshpid = -1
		return
	
	fout.open(fmeshname, File.READ)
	var x = parse_json(fout.get_line())
	fout.close()
	print("triangulation received with %d points and %d faces" % [len(x[0]), len(x[1])/3])
	var nvertices = [ ]
	for i in range(len(x[0])):
		var v = x[0][i]
		var z = (0.01 if (int(i/3)%2) == 0 else -0.01)
		nvertices.push_back(Vector3(v[0], v[1], z))
	sketchsystem.actsketchchange([{"name":xcdrawingname, "wingmesh":{"vertices":nvertices, "triangles":x[1]}}])

	if xcropedrawingwing == null:
		print("no ropexcsurface for wing")
		pymeshpid = -1
		return
		
	var nsurfacevertices = [ ]
	var triangles = x[1]
	for v in x[0]:
		var uv = Vector2(clamp(v[0]/Tglobal.wingmeshuvexpansionfac, 0, 1), 
						 clamp(v[1]/Tglobal.wingmeshuvexpansionfac, 0, 1))
		var sprojpoint = xcropedrawingwing.ropepointreprojectXYZ(uv, sketchsystem)
		nsurfacevertices.push_back(sprojpoint)
	#sketchsystem.actsketchchange([{"name":xcropedrawingwing.get_name(), "wingmesh":{"vertices":nsurfacevertices, "triangles":x[1]}}])

	var fsurfacemeshname = "user://executingfeatures/surfacemesh.txt"
	var fflattenedmeshname = "user://executingfeatures/flattenedmesh.txt"
	if fout.file_exists(fflattenedmeshname):
		dir.remove(fflattenedmeshname)
	
	var svertices = [ ]
	for p in nsurfacevertices:
		svertices.push_back([p.x, p.y, p.z])
	fout.open(fsurfacemeshname, File.WRITE)
	fout.store_line(to_json([svertices, triangles]))
	fout.close()

	var freecadappimage = "/home/julian/executables/FreeCAD_0.19-24267-Linux-Conda_glibc2.12-x86_64.AppImage"
	var fmeshflattenerpy = "res://executingfeatures/meshflattener.py"

	var arguments = PoolStringArray([
			ProjectSettings.globalize_path(fmeshflattenerpy), 
			ProjectSettings.globalize_path(freecadappimage), 
			ProjectSettings.globalize_path(fsurfacemeshname), 
			ProjectSettings.globalize_path(fflattenedmeshname)])
	pymeshpid = OS.execute("python", arguments, false)
	print(pymeshpid, arguments)
	if pymeshpid == -1:
		print("fail")
		return
	
	for i in range(10):
		yield(get_tree().create_timer(1.0), "timeout")
		if fout.file_exists(fflattenedmeshname):
			break
		print("waiting on mesh flattener ", i)
	if not fout.file_exists(fflattenedmeshname):
		print("no file after 10 seconds, kill")
		OS.kill(pymeshpid)
		pymeshpid = -1
		return

	fout.open(fflattenedmeshname, File.READ)
	var px = parse_json(fout.get_line())
	fout.close()
	print("flattened points %d received" % [len(px)])
	var flattenedvertices = [ ]
	for v in x[0]:
		flattenedvertices.push_back(Vector2(v[0], v[1]))
	sketchsystem.actsketchchange([{"name":xcropedrawingwing.get_name(), "wingmesh":{"vertices":nsurfacevertices, "triangles":x[1], "flattenedvertices":flattenedvertices}}])

	pymeshpid = -1




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


