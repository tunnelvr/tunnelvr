extends Spatial

const CentrelineStationNode = preload("res://nodescenes/CentrelineStationNode.tscn")

func Loadcentrelinefile(fname):
	var centrelinedatafile = File.new()
	centrelinedatafile.open(fname, File.READ)
	var centrelinedata = parse_json(centrelinedatafile.get_line())

	# create all the centreline nodes
	var centrelinegnodes = $CentrelineNodes
	# centrelinegnodes.clear()  queue_free() ?
	assert (len(centrelinegnodes.get_children()) == 0)
	var stationpointscoords = centrelinedata.stationpointscoords
	var stationpointsnames = centrelinedata.stationpointsnames
	var stationpoints = [ ]
	for i in range(len(stationpointsnames)):
		var csn = CentrelineStationNode.instance()
		centrelinegnodes.add_child(csn)
		var stationpoint = Vector3(stationpointscoords[i*3], 8+stationpointscoords[i*3+2], -stationpointscoords[i*3+1])
		stationpoints.append(stationpoint)
		csn.global_transform.origin = stationpoint
		csn.stationname = stationpointsnames[i]

	# create all the centreline joins
	var linewidth = 0.09
	var legsconnections = centrelinedata.legsconnections
	var legsstyles = centrelinedata.legsstyles
	var surfaceTool = SurfaceTool.new()
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(len(legsstyles)):
		var p0 = stationpoints[legsconnections[i*2]]
		var p1 = stationpoints[legsconnections[i*2+1]]
		var perp = linewidth*Vector2(-(p1.z - p0.z), p1.x - p0.x).normalized()
		if perp == Vector2(0, 0):
			perp = Vector2(0, linewidth)
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
	$CentrelineLegs.mesh = surfaceTool.commit()
	print("udddddsus ", len($CentrelineLegs.mesh.get_faces()), " ", len($CentrelineLegs.mesh.get_faces())) #surfaceTool.generate_normals()

	# create all the centreline joins
	var xsectgps = centrelinedata.xsectgps
	var surfaceToolXS = SurfaceTool.new()
	surfaceToolXS.begin(Mesh.PRIMITIVE_TRIANGLES)
	for xsectgp in xsectgps:
		var xsectindexes = xsectgp.xsectindexes
		var xsectrightvecs = xsectgp.xsectrightvecs
		var xsectlruds = xsectgp.xsectlruds
		for i in range(len(xsectindexes)):
			var p = stationpoints[xsectindexes[i]]
			var vright = Vector3(xsectrightvecs[i*2], 0, -xsectrightvecs[i*2+1])
			var vup = Vector3(0, 1, 0)
			var pRU = p + vright*xsectlruds[i*4 + 1] + vup*xsectlruds[i*4 + 2]
			var pRD = p + vright*xsectlruds[i*4 + 1] - vup*xsectlruds[i*4 + 3]
			var pLU = p - vright*xsectlruds[i*4] + vup*xsectlruds[i*4 + 2]
			var pLD = p - vright*xsectlruds[i*4] - vup*xsectlruds[i*4 + 3]
			surfaceToolXS.add_vertex(pLD)
			surfaceToolXS.add_vertex(pLU)
			surfaceToolXS.add_vertex(pRD)
			surfaceToolXS.add_vertex(pRD)
			surfaceToolXS.add_vertex(pLU)
			surfaceToolXS.add_vertex(pRU)
	surfaceToolXS.generate_normals()
	$CentrelineCrossSections.mesh = surfaceToolXS.commit()
	print("udddddsusXC ", len($CentrelineCrossSections.mesh.get_faces()), " ", len($CentrelineCrossSections.mesh.get_faces())) #surfaceTool.generate_normals()


# Called when the node enters the scene tree for the first time.
func _ready():
	Loadcentrelinefile("res://surveyscans/dukest1resurvey2009.json")

