extends Spatial

const CentrelineStationNode = preload("res://CentrelineStationNode.tscn")

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
		var stationpoint = Vector3(stationpointscoords[i*3], 8+stationpointscoords[i*3+2], stationpointscoords[i*3+1])
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

# Called when the node enters the scene tree for the first time.
func _ready():
	Loadcentrelinefile("res://surveyscans/dukest1resurvey2009.json")

