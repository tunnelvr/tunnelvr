extends Node


func _ready():
	$RayCast.collision_mask = CollisionLayer.CL_CaveWall

func addwaterlevelfan(surfaceTool, cpt, vf):
	var vfperp = Vector2(vf.y, -vf.x)
	var prevvv = null
	var prevpr = null
	for i in range(11):
		var a = deg2rad((i - 5)/5.0*45)
		var vv = cos(a)*vf - sin(a)*vfperp
		var pr = cpt + Vector3(vv.x, 0, vv.y)
		if i != 0:
			surfaceTool.add_uv(Vector2(0, 0))
			surfaceTool.add_vertex(cpt)
			surfaceTool.add_uv(prevvv)
			surfaceTool.add_vertex(prevpr)
			surfaceTool.add_uv(vv)
			surfaceTool.add_vertex(pr)
		prevvv = vv
		prevpr = pr

func xcdrawingslice(xcdrawing, yval):
	var res = [ ]
	for i in range(0, len(xcdrawing.onepathpairs), 2):
		var s0 = xcdrawing.onepathpairs[i]
		var s1 = xcdrawing.onepathpairs[i+1]
		var p0 = xcdrawing.transform.xform(xcdrawing.nodepoints[s0])
		var p1 = xcdrawing.transform.xform(xcdrawing.nodepoints[s1])
		if (p0.y < yval) != (p1.y < yval):
			var lam = inverse_lerp(p0.y, p1.y, yval)
			var pm = lerp(Vector2(p0.x, p0.z), Vector2(p1.x, p1.z), lam)
			res.push_back(pm)
	return res
	
func addwaterleveltube(surfaceTool, xcdrawing0, xcdrawing1, xctube, yval):
	var tubesectormeshes = [ ]
	for xctubesector in xctube.get_node("XCtubesectors").get_children():
		tubesectormeshes.push_back(xctubesector.get_node("MeshInstance").mesh)
		# PoolVector3Array get_faces() const
	var xcdp0 = xcdrawingslice(xcdrawing0, yval)
	var xcdp1 = xcdrawingslice(xcdrawing1, yval)
	var poly = xcdp0 + xcdp1
	var pi = Geometry.triangulate_polygon(PoolVector2Array(poly))
	for u in pi:
		surfaceTool.add_uv(poly[u])
		surfaceTool.add_vertex(Vector3(poly[u].x, yval, poly[u].y))


func drawwaterlevelmesh(sketchsystem, waterflowlevelvectors, nodepoints):
	var raycast = $RayCast
	var xctubes = sketchsystem.get_node("XCtubes")
	var xcdrawings = sketchsystem.get_node("XCdrawings")
	var arraymesh = ArrayMesh.new()
	var surfaceTool = SurfaceTool.new()
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for nodename in waterflowlevelvectors:
		var cpt = nodepoints[nodename]
		raycast.transform.origin = cpt
		raycast.cast_to = Vector3(0, -10, 0)
		raycast.force_raycast_update()
		var watertube = raycast.get_collider()
		if watertube != null:
			var nodepath = watertube.get_path()
			var w2 = nodepath.get_name(2)
			var w3 = nodepath.get_name(3)
			if w2 == "SketchSystem" and w3 == "XCtubes":
				var tubename = nodepath.get_name(4)
				var xctube = xctubes.get_node(tubename)
				var xcdrawing0 = xcdrawings.get_node(xctube.xcname0)
				var xcdrawing1 = xcdrawings.get_node(xctube.xcname1)
				addwaterleveltube(surfaceTool, xcdrawing0, xcdrawing1, xctube, cpt.y)
				continue
		addwaterlevelfan(surfaceTool, cpt, -Vector2(waterflowlevelvectors[nodename].x, waterflowlevelvectors[nodename].z)*4)

	surfaceTool.generate_normals()
	surfaceTool.generate_tangents()
	surfaceTool.commit(arraymesh)
	return arraymesh
