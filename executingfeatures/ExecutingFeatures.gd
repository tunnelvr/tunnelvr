extends Node

var caddywebserverpid = -1

# This is where we store the potree files on the server; 
# in a directory:  /home/julian/.local/share/godot/app_userdata/tunnelvr_v0.7/caddywebserver
# or /var/lib/tunnelvr/.local/share/godot/app_userdata/tunnelvr_v0.7/caddywebserver
func startcaddywebserver():
	if caddywebserverpid != -1:
		stopcaddywebserver()
	var dir = Directory.new()
	if not dir.dir_exists("user://caddywebserver"):
		dir.make_dir("user://caddywebserver")
	var arguments = PoolStringArray([
			"file-server", 
			"--browse", 
			"--root", ProjectSettings.globalize_path("user://caddywebserver"), 
			"--listen", "0.0.0.0:8000" ])
	caddywebserverpid = OS.execute("caddy", arguments, false)
	print(caddywebserverpid, " caddy ", arguments)

func stopcaddywebserver():
	if caddywebserverpid != -1:
		OS.kill(caddywebserverpid)
		caddywebserverpid = -1

func _exit_tree():
	stopcaddywebserver()

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
		var trilineleng = 0.100
		
		call_deferred("finemeshpolygon_execute", polypoints, trilineleng, xcdrawing.get_name())
	else:
		rpc_id(playerwithexecutefeatures.networkID, "finemeshpolygon_execute", polypoints, 0.25, xcdrawing.get_name())
		print("rpc on finemeshpolygon_execute")
		

var pymeshpid = -1
remote func finemeshpolygon_execute(polypoints, trilineleng, xcdrawingname):
	var trilineshortleng = trilineleng/4
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

	for i in range(len(polypoints)):
		polypoints[i].x = clamp(polypoints[i].x, 0, Tglobal.wingmeshuvexpansionfac)
		polypoints[i].y = clamp(polypoints[i].y, 0, Tglobal.wingmeshuvexpansionfac)
	
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
	var dc = "run -it --rm -v %s:/data -v %s:/code pymesh/pymesh /code/polytriangulator.py /data/polygon.txt /data/mesh.txt %f %f" % \
		[ ProjectSettings.globalize_path("user://executingfeatures"), ProjectSettings.globalize_path("res://executingfeatures"), trilineleng, trilineshortleng ]
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
	var jtxt = fout.get_line()
	fout.close()
	var px = parse_json(jtxt)
	if px != null:
		print("flattened points %d received" % [len(px)])
		var flattenedvertices = [ ]
		for v in px:
			flattenedvertices.push_back(Vector2(v[0], v[1]))
		sketchsystem.actsketchchange([{"name":xcropedrawingwing.get_name(), "wingmesh":{"vertices":nsurfacevertices, "triangles":x[1], "flattenedvertices":flattenedvertices}}])
	else:
		print("dud flattening output ", jtxt.substr(0, 15))
	pymeshpid = -1


func find_executingfeaturesavailable():
	var playerplatform = get_node("/root/Spatial").playerMe.playerplatform	
	var executingfeaturesavailable = [ ]
	if playerplatform == "PC" or playerplatform == "Server":
		var ffindexecutingfeaturespy = copytouserfilesystem("res://surveyscans/find_executingfeatures.py")
		var arguments = PoolStringArray([ffindexecutingfeaturespy])
		var output = [ ]
		# this is where parse3ddmp_centreline gets added
		var ffindexecutingfeaturespy_status = OS.execute("python", arguments, true, output)
		if ffindexecutingfeaturespy_status == 0 and len(output) == 1:
			executingfeaturesavailable = Array(output[0].split(" "))

		var caddyarguments = PoolStringArray(["version"])
		output = [ ]
		var caddyoutputstatus = OS.execute("caddy", caddyarguments, true, output)
		if caddyoutputstatus == 0:
			executingfeaturesavailable.push_back("caddy")
	return executingfeaturesavailable


















func copytouserfilesystem(f):
	var dir = Directory.new()
	if not dir.dir_exists("user://executingfeatures"):
		dir.make_dir("user://executingfeatures")
	var fname = f.rsplit("/")[-1]
	var dest = "user://executingfeatures/"+fname
	if true or not dir.file_exists(dest):
		print("Copying out our py file ", fname)
		var e = dir.copy(f, dest)
		if e != 0:
			print("copytousrfilesystem ERROR ", e)
	return ProjectSettings.globalize_path(dest)



func parse3ddmpcentreline_networked(f3durl):
	var sketchsystem = get_node("/root/Spatial/SketchSystem")
	if sketchsystem.caveworldchunkI != -1 or parse3ddmpcentrelinepid != -1:
		print("Cannot start centreline processing when already caveworld chunking")
		return

	var playerwithexecutefeatures = null
	for player in get_node("/root/Spatial/Players").get_children():
		if player.executingfeaturesavailable.has("parse3ddmp_centreline"):
			playerwithexecutefeatures = player
			break
			
	if playerwithexecutefeatures == null:
		print("no player able to execute parse3ddmp_centreline")
		return
	elif playerwithexecutefeatures.networkID == get_node("/root/Spatial").playerMe.networkID:
		print("locally calling parse3ddmpcentreline_execute")
		call_deferred("fetch3dcentreline_execute", f3durl)
	else:
		print("rpc on parse3ddmpcentreline_execute networkdid=", playerwithexecutefeatures.networkID)
		rpc_id(playerwithexecutefeatures.networkID, "fetch3dcentreline_execute", f3durl)
		
remote func fetch3dcentreline_execute(f3durl):
	var ImageSystem = get_node("/root/Spatial/ImageSystem")
	var nonimagedataobject = { "url":f3durl, "parsedumpcentreline":"yes" }
	ImageSystem.fetchnonimagedataobject(nonimagedataobject)

var parse3ddmpcentrelinepid = -1
func parse3ddmpcentreline_execute(f3dfile, f3durl):
	print("entering parse3ddmpcentreline_execute")
	if parse3ddmpcentrelinepid != -1:
		print("already busy")
		return
	parse3ddmpcentrelinepid = 0
	
	var dir = Directory.new()
	if not dir.dir_exists("user://executingfeatures"):
		dir.make_dir("user://executingfeatures")
	var jcentreline = "user://executingfeatures/fcentreline.json"

	var fout = File.new()
	if fout.file_exists(jcentreline):
		dir.remove(jcentreline)
	
	var fparse3ddmppy = copytouserfilesystem("res://surveyscans/parse3ddmp.py")
	var arguments = PoolStringArray([
			fparse3ddmppy, 
			"--3d="+ProjectSettings.globalize_path(f3dfile), 
			"--js="+ProjectSettings.globalize_path(jcentreline), 
			"--tunnelvr"])
	print("python ", arguments)
	parse3ddmpcentrelinepid = OS.execute("python", arguments, false)
	print(parse3ddmpcentrelinepid, arguments)
	if parse3ddmpcentrelinepid == -1:
		print("fail")
		return
	
	for i in range(10):
		yield(get_tree().create_timer(0.8), "timeout")
		if fout.file_exists(jcentreline):
			break
		print("parse3d ", i)
	if not fout.file_exists(jcentreline):
		print("no file after 10 seconds, kill")
		OS.kill(parse3ddmpcentrelinepid)
		parse3ddmpcentrelinepid = -1
		return
	parse3ddmpcentrelinepid = -1

	var maxcentrelinenumber = -1
	for xcdrawingcentreline in get_tree().get_nodes_in_group("gpcentrelinegeo"):
		maxcentrelinenumber = max(maxcentrelinenumber, int(xcdrawingcentreline.get_name()))
	var sketchdatadict = Centrelinedata.sketchdatadictlistfromcentreline(jcentreline, (maxcentrelinenumber+1)*2)
	if sketchdatadict == null:
		return
	sketchdatadict["xcdrawings"][0]["name"] = "centreline%d" % (maxcentrelinenumber+1)
	var sketchsystem = get_node("/root/Spatial/SketchSystem")
	#xcdatalist[0]["sketchname"] = f3durl.split("/")[-1].split(".")[0]
	sketchdatadict["xcdrawings"][0]["xcresource"] = f3durl
	sketchdatadict["sketchname"] = "importing_the_centreline__do_not_clear"
	var xcdatachunks = sketchsystem.sketchdicttochunks(sketchdatadict)
	print("Centreline split into ", len(xcdatachunks), " chunks")
	for xcdatachunk in xcdatachunks:
		yield(get_tree().create_timer(0.2), "timeout")
		sketchsystem.actsketchchange(xcdatachunk)
	#sketchsystem.rpc_id(id, "actsketchchangeL", [{"planview":$PlanViewSystem.planviewtodict()}]) 


func _ready():
	print("The PATH environment is: ", OS.get_environment("PATH").substr(0, 100), "\n\n")


func _input(event):	
	if event is InputEventKey and event.pressed and event.scancode == KEY_4:
		var sketchsystem = get_node("/root/Spatial/SketchSystem")
		var rnodepoints = { }
		var ronepathpairs = [ ]
		var ri = 2.8
		var ro = 3.7
		var rh = 0.9
		var sweepdeg = 170.0
		var hump = 0.8
		var en = { "li":5, "lo":6, "hi":5, "ho":10}
		var ens = {0:4, 100:3}
		for l in en:
			var rn = en[l]
			var np = ""
			for i in range(rn+1):
				var ang = i*1.0/rn*sweepdeg+0
				var j = int(i*1.0/rn*100 + 0.5)
				var ct = cos(deg2rad(ang))
				var st = sin(deg2rad(ang))
				var r = ri if l[1] == "i" else ro
				var nn = "%s%d" % [l, j]
				rnodepoints[nn] = Vector3(ct*r, (0 if l[0] == "l" else rh), st*r)
				if i != 0:
					ronepathpairs.append_array([nn, np])
				np = nn
		for l in ens:
			var ni = rnodepoints["hi%d" % l]
			var no = rnodepoints["ho%d" % l]
			var rn = ens[l]
			var np = "hi%d"%l
			for i in range(1, rn):
				var a = i*1.0/rn
				var nn = "h%dt%d" % [l, i]
				rnodepoints[nn] = lerp(ni, no, a) + Vector3(0, hump*(1 - 4*pow(a-0.5, 2)), 0)
				ronepathpairs.append_array([np, nn])
				np = nn
			ronepathpairs.append_array([np, "ho%d" % l])
				
		ronepathpairs.append_array(["li0","lo0", "lo0","ho0", "hi0","li0",  "li100","lo100", "lo100","ho100", "hi100","li100"])
		var xcboulder = { "name":"rock2", 
						  "drawingtype":DRAWING_TYPE.DT_ROPEHANG, 
						  "drawingvisiblecode":DRAWING_TYPE.VIZ_XCD_NODES_VISIBLE,
						  "transformpos":Transform(Basis(), Vector3(10, 0.2, -12)), 
						  "nodepoints":rnodepoints,
						  "onepathpairs":ronepathpairs, 
						 }
		sketchsystem.actsketchchange([xcboulder])


