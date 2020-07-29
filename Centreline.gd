extends Spatial

const StationNode = preload("res://nodescenes/StationNode.tscn")
const DrawnStationNode = preload("res://nodescenes/DrawnStationNode.tscn")
var stationnodemap = { }
var drawnfloor = null   # filled in by Spatial.gd
var floordrawing = null

func newdrawnstationnode():
	var dsn = DrawnStationNode.instance()
	$DrawnStationNodes.add_child(dsn)
	return dsn

func shiftfloorfromdrawnstations():
	# compatible with setopnpos(opn, p)
	var drawnstationnodes = $DrawnStationNodes.get_children()
	if len(drawnstationnodes) == 0:
		return
		
	var drawnstationnodesCopiesInFloor = [ ]
	for i in range(len(drawnstationnodes)):
		var drawnstationnodeCopy = Spatial.new()
		floordrawing.get_node("XCdrawingplane").add_child(drawnstationnodeCopy)
		drawnstationnodeCopy.global_transform.origin = drawnstationnodes[i].global_transform.origin
		drawnstationnodesCopiesInFloor.append(drawnstationnodeCopy)

	var dsn0 = drawnstationnodes[-1]
	var dsnC0 = drawnstationnodesCopiesInFloor[-1]
	var pdsn0 = dsn0.global_transform.origin
	var st0 = stationnodemap[dsn0.stationname]
	var pst0 = st0.global_transform.origin
	print(" dsnC0", dsnC0.global_transform.origin)	

	if len(drawnstationnodes) >= 2:
		var dsn1 = drawnstationnodes[-2]
		var dsnC1 = drawnstationnodesCopiesInFloor[-2]
		var st1 = stationnodemap[dsn1.stationname]
		var pst1 = st1.global_transform.origin
		var pdsn1 = dsn1.global_transform.origin
			
		var vpst = Vector2(pst1.x, pst1.z) - Vector2(pst0.x, pst0.z)
		var vdsn = Vector2(pdsn1.x, pdsn1.z) - Vector2(pdsn0.x, pdsn0.z)
		var sca = vpst.length()/vdsn.length()
		var ang = vpst.angle() - vdsn.angle()
		
		print(" vpst", vpst, vpst.length())	
		print(" vdsn", vdsn, vdsn.length())	
		print(" sssca ", sca, "  ", ang)
		floordrawing.get_node("XCdrawingplane").scale_object_local(Vector3(sca, sca, 1.0)) 
		floordrawing.rotate_y(-ang)
	
	# now translate to match the new position dsnC0 has gone to
	print(" dsnC0", dsnC0.global_transform.origin)	
	print(" st0", st0.global_transform.origin)
	floordrawing.global_translate(Vector3(st0.global_transform.origin.x - dsnC0.global_transform.origin.x, 0, st0.global_transform.origin.z - dsnC0.global_transform.origin.z)) 
	
	for i in range(len(drawnstationnodes)):
		drawnstationnodes[i].global_transform.origin = drawnstationnodesCopiesInFloor[i].global_transform.origin
		floordrawing.get_node("XCdrawingplane").remove_child(drawnstationnodesCopiesInFloor[i])
		print("floor shiftingggg")
		

func Loadcentrelinefile(fname):
	var centrelinedatafile = File.new()
	centrelinedatafile.open(fname, File.READ)
	var centrelinedata = parse_json(centrelinedatafile.get_line())

	# create all the centreline nodes
	# $StationNodes.clear()  queue_free() ?
	assert (len($StationNodes.get_children()) == 0)
	var stationpointscoords = centrelinedata.stationpointscoords
	var stationpointsnames = centrelinedata.stationpointsnames
	var stationpoints = [ ]
	for i in range(len(stationpointsnames)):
		var csn = StationNode.instance()
		$StationNodes.add_child(csn)
		var stationpoint = Vector3(stationpointscoords[i*3], 8+stationpointscoords[i*3+2], -stationpointscoords[i*3+1])
		stationpoints.append(stationpoint)
		csn.global_transform.origin = stationpoint
		csn.stationname = stationpointsnames[i]
		stationnodemap[csn.stationname] = csn

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

