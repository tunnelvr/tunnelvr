extends Spatial

const XCnode = preload("res://nodescenes/XCnode.tscn")
const XCnode_centreline = preload("res://nodescenes/XCnode_centreline.tscn")

# primary data
var xcname = ""         # must match what is in the godot and used for the names in xctube
var xcresource = ""     # source file
var nodepoints = { }    # { nodename:Vector3 }
var onepathpairs = [ ]  # [ Anodename0, Anodename1, Bnodename0, Bnodename1, ... ]
var drawingtype = DRAWING_TYPE.DT_XCDRAWING
var xcflatshellmaterial = "simpledirt"

# derived data
var xctubesconn = [ ]   # references to xctubes that connect to here (could use their names instead)
var maxnodepointnumber = 0

var linewidth = 0.05

func setxcdrawingvisibility(makevisible):
	assert ($XCdrawingplane.visible != $XCdrawingplane/CollisionShape.disabled)	
	if not makevisible:
		$XCdrawingplane.visible = false
		$XCdrawingplane/CollisionShape.disabled = true
		#$XCnodes.visible = Tglobal.tubedxcsvisible or (drawingtype != DRAWING_TYPE.DT_XCDRAWING) or (len(xctubesconn) == 0)
		#$PathLines.visible = $XCnodes.visible
	elif makevisible != $XCdrawingplane.visible:
		$XCdrawingplane.visible = true
		$XCdrawingplane/CollisionShape.disabled = false
		$XCnodes.visible = true
		$PathLines.visible = true
		if drawingtype == DRAWING_TYPE.DT_XCDRAWING:
			var sca = 1.0
			for nodepoint in nodepoints.values():
				sca = max(sca, abs(nodepoint.x) + 1)
				sca = max(sca, abs(nodepoint.y) + 1)
			if sca > $XCdrawingplane.scale.x:
				$XCdrawingplane.set_scale(Vector3(sca, sca, 1.0))
	assert ($XCdrawingplane.visible != $XCdrawingplane/CollisionShape.disabled)
	
# these transforming operations work in sequence, each correcting the relative position change caused by the other
func scalexcnodepointspointsxy(scax, scay):
	for i in nodepoints.keys():
		nodepoints[i] = Vector3(nodepoints[i].x*scax, nodepoints[i].y*scay, nodepoints[i].z)
		$XCnodes.get_node(i).translation = nodepoints[i]
	
func setxcpositionangle(drawingwallangle):
	global_transform = Transform(Basis().rotated(Vector3(0,-1,0), drawingwallangle), global_transform.origin)

func setxcpositionorigin(pt0):
	global_transform.origin = pt0
	
remote func setxcdrawingposition(lglobal_transform):
	global_transform = lglobal_transform

func exportxcrpcdata():
	return { "name":get_name(), 
			 "xcresource":xcresource,
			 "drawingtype":drawingtype,
			 "transformpos":global_transform,
			 "shapeimage":[$XCdrawingplane.scale.x, $XCdrawingplane.scale.y],
			 "nodepoints": nodepoints, 
			 "onepathpairs":onepathpairs,
			 "maxnodepointnumber":maxnodepointnumber,
			 "visible":$XCdrawingplane.visible 
		   }

func mergexcrpcdata(xcdata):
	assert ((get_name() == xcdata["name"]) and (drawingtype == xcdata["drawingtype"]))
	global_transform = xcdata["transformpos"]
	nodepoints = xcdata["nodepoints"]
	maxnodepointnumber = xcdata["maxnodepointnumber"]
	onepathpairs = xcdata["onepathpairs"]
	$XCdrawingplane.set_scale(Vector3(xcdata["shapeimage"][0], xcdata["shapeimage"][1], 1.0))
	for xcn in $XCnodes.get_children():
		if not nodepoints.has(xcn.get_name()):
			xcn.queue_free()
	for k in nodepoints:
		var xcn = $XCnodes.get_node(k) if $XCnodes.has_node(k) else null
		if xcn == null:
			xcn = XCnode_centreline.instance() if drawingtype == DRAWING_TYPE.DT_CENTRELINE else XCnode.instance()
			xcn.set_name(k)
			$XCnodes.add_child(xcn)
		xcn.translation = nodepoints[k]
	updatexcpaths()
	setxcdrawingvisibility(xcdata["visible"])

func importcentrelinedata(centrelinedata, sketchsystem):
	$XCdrawingplane.visible = false
	$XCdrawingplane/CollisionShape.disabled = true
	drawingtype = DRAWING_TYPE.DT_CENTRELINE
	#assert (get_name() == "centreline")
	assert ($XCnodes.get_child_count() == 0 and len(nodepoints) == 0 and len(onepathpairs) == 0 and len(xctubesconn) == 0)

	var stationpointscoords = centrelinedata.stationpointscoords
	var stationpointsnames = centrelinedata.stationpointsnames
	var legsconnections = centrelinedata.legsconnections
	var legsstyles = centrelinedata.legsstyles
	
	# find centre (should use an AABB function if exists)
	var bb = [ stationpointscoords[0], stationpointscoords[1], stationpointscoords[2], 
			   stationpointscoords[0], stationpointscoords[1], stationpointscoords[2] ]
	for i in range(len(stationpointsnames)):
		for j in range(3):
			bb[j] = min(bb[j], stationpointscoords[i*3+j])
			bb[j+3] = max(bb[j+3], stationpointscoords[i*3+j])
	print("svx bounding box", bb)		
	$XCdrawingplane.set_scale(Vector3(1,1,1))
	global_transform = Transform()
	var stationpoints = [ ]
	for i in range(len(stationpointsnames)):
		var stationpointname = stationpointsnames[i].replace(".", ",")   # dots not allowed in node name, but commas are
		stationpointsnames[i] = stationpointname
		#nodepoints[k] = Vector3(stationpointscoords[i*3], 8.1+stationpointscoords[i*3+2], -stationpointscoords[i*3+1])
		var stationpoint = Vector3(stationpointscoords[i*3] - (bb[0]+bb[3])/2, 
								   stationpointscoords[i*3+2] - bb[2] + 1, 
								   -(stationpointscoords[i*3+1] - (bb[1]+bb[4])/2))
		nodepoints[stationpointname] = stationpoint
		stationpoints.append(stationpoint)
		var xcn = XCnode_centreline.instance()
		$XCnodes.add_child(xcn)
		xcn.set_name(stationpointname)
		xcn.translation = nodepoints[stationpointname]
		maxnodepointnumber = max(maxnodepointnumber, int(stationpointname))
	for i in range(len(legsstyles)):
		onepathpairs.append(stationpointsnames[legsconnections[i*2]])
		onepathpairs.append(stationpointsnames[legsconnections[i*2+1]])
	updatexcpaths()

	# now make the cross sections
	var xsectgps = centrelinedata.xsectgps
	var hexonepathpairs = [ "hl","hu", "hu","hv", "hv","hr", "hr","he", "he","hd", "hd","hl"]
	for j in range(len(xsectgps)):
		var xsectgp = xsectgps[j]
		var xsectindexes = xsectgp.xsectindexes
		var xsectrightvecs = xsectgp.xsectrightvecs
		var xsectlruds = xsectgp.xsectlruds

		var xcdrawingSect = null
		for i in range(len(xsectindexes)):
			var sname = stationpointsnames[xsectindexes[i]]+"s"+String(j)
			if sketchsystem.get_node("XCdrawings").has_node(sname):
				continue
			var hexnodepoints = { }
			var xl = max(0.1, xsectlruds[i*4+0])
			var xr = max(0.1, xsectlruds[i*4+1])
			var xu = max(0.1, xsectlruds[i*4+2])
			var xd = max(0.1, xsectlruds[i*4+3])
			hexnodepoints["hl"] = Vector3(-xl, 0, 0)
			hexnodepoints["hr"] = Vector3(xr, 0, 0)
			hexnodepoints["hu"] = Vector3(-xl/2, xu, 0)
			hexnodepoints["hv"] = Vector3(+xr/2, xu, 0)
			hexnodepoints["hd"] = Vector3(-xl/2, -xd, 0)
			hexnodepoints["he"] = Vector3(+xr/2, -xd, 0)

			var p = stationpoints[xsectindexes[i]]
			var ang = Vector2(xsectrightvecs[i*2], -xsectrightvecs[i*2+1]).angle()
			var xcdrawingSect1 = sketchsystem.newXCuniquedrawing(DRAWING_TYPE.DT_XCDRAWING, sname)
			assert (xcdrawingSect1.get_name() == sname)
			var xcdata = { "name":xcdrawingSect1.get_name(), "xcresource":"station_"+sname, "drawingtype":DRAWING_TYPE.DT_XCDRAWING, 
						   "transformpos":Transform(Basis().rotated(Vector3(0,-1,0), ang), p), "maxnodepointnumber":0, 
						   "shapeimage":[max(xsectlruds[i*4], xsectlruds[i*4+1])+1, max(xsectlruds[i*4+2], xsectlruds[i*4+3])+1], 
						   "nodepoints":hexnodepoints, "onepathpairs":hexonepathpairs.duplicate(), "visible":false 
						 }

			xcdrawingSect1.mergexcrpcdata(xcdata)
			if xcdrawingSect != null:
				var xctube = sketchsystem.newXCtube(xcdrawingSect, xcdrawingSect1)
				xctube.xcdrawinglink = ["hl", "hl", "hr", "hr"].duplicate()
				xctube.updatetubelinkpaths(sketchsystem)
			xcdrawingSect = xcdrawingSect1
	
func setxcnpoint(xcn, pt, planar):
	xcn.global_transform.origin = pt
	nodepoints[xcn.get_name()] = xcn.translation
	if planar:
		nodepoints[xcn.get_name()].z = 0
		xcn.translation = nodepoints[xcn.get_name()]
		
func xcotapplyonepath(i0, i1):
	for j in range(len(onepathpairs)-2, -3, -2):
		if j == -2:
			print("addingonepath ", len(onepathpairs), " ", i0, " ", i1)
			onepathpairs.push_back(i0)
			onepathpairs.push_back(i1)
		elif (onepathpairs[j] == i0 and onepathpairs[j+1] == i1) or (onepathpairs[j] == i1 and onepathpairs[j+1] == i0):
			onepathpairs[j] = onepathpairs[-2]
			onepathpairs[j+1] = onepathpairs[-1]
			onepathpairs.resize(len(onepathpairs) - 2)
			print("deletedonepath ", j)
			break

func newxcnode(name=null):
	var xcn = XCnode.instance()
	if name == null:
		maxnodepointnumber += 1
		xcn.set_name("p"+String(maxnodepointnumber))
	else:
		xcn.set_name(name)
		maxnodepointnumber = max(maxnodepointnumber, int(name))
		
	nodepoints[xcn.get_name()] = Vector3()
	assert (not $XCnodes.has_node(xcn.get_name()))
	$XCnodes.add_child(xcn)
	return xcn

func clearallcontents():
	onepathpairs.clear()
	for xcn in $XCnodes.get_children():
		xcn.queue_free()
	nodepoints.clear()
	assert (len(xctubesconn) == 0)  # for now

func removexcnode(xcn, brejoinlines, sketchsystem):
	var nodename = xcn.get_name()
	nodepoints.erase(nodename)
	var rejoinnodes = [ ]
	for j in range(len(onepathpairs) - 2, -1, -2):
		if (onepathpairs[j] == nodename) or (onepathpairs[j+1] == nodename):
			rejoinnodes.append(onepathpairs[j+1]  if onepathpairs[j] == nodename  else onepathpairs[j])
			onepathpairs[j] = onepathpairs[-2]
			onepathpairs[j+1] = onepathpairs[-1]
			onepathpairs.resize(len(onepathpairs) - 2)
	print("brejoinlinesbrejoinlinesbrejoinlinesbrejoinlines ", brejoinlines, " ", rejoinnodes)
	if brejoinlines and len(rejoinnodes) >= 2:
		onepathpairs.append(rejoinnodes[0])
		onepathpairs.append(rejoinnodes[1])
	xcn.queue_free()
	var	xctubesconnupdated = [ ]
	for xctube in xctubesconn:
		if xctube.removetubenodepoint(get_name(), nodename):  # might extend to a batch operation when sequence of points deleted at once (though sequence terminates at one of these junctions anyway)
			xctubesconnupdated.append(xctube)
	updatelinksandtubesafterchange(xctubesconnupdated, sketchsystem)

func movexcnode(xcn, pt, sketchsystem):
	print("m,mmmmxmxmxm ", xcn.global_transform.origin, pt)
	setxcnpoint(xcn, pt, true)
	var	xctubesconnupdated = [ ]
	for xctube in xctubesconn:
		if xctube.checknodelinkedto(get_name(), xcn.get_name()):
			xctubesconnupdated.append(xctube)
	updatelinksandtubesafterchange(xctubesconnupdated, sketchsystem)

func updatelinksandtubesafterchange(xctubesconnupdated, sketchsystem):
	updatexcpaths()
	var	xcdrawingnamesmoved = [ get_name() ]
	for xctube in xctubesconnupdated:
		if xctube.positioningtube:
			xctube.positionfromtubelinkpaths(sketchsystem)
			if not xcdrawingnamesmoved.has(xctube.xcname1):
				xcdrawingnamesmoved.append(xctube.xcname1)
		
	for xcdrawingname in xcdrawingnamesmoved:
		sketchsystem.sharexcdrawingovernetwork(sketchsystem.get_node("XCdrawings").get_node(xcdrawingname))
	for xctube in xctubesconnupdated:
		xctube.updatetubelinkpaths(sketchsystem)
		sketchsystem.sharexctubeovernetwork(xctube)

func updatexcpaths():
	if drawingtype == DRAWING_TYPE.DT_PAPERTEXTURE:
		return
	if len(onepathpairs) == 0:
		$PathLines.mesh = null
		return
		
	var surfaceTool = SurfaceTool.new()
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in range(0, len(onepathpairs), 2):
		var p0 = nodepoints[onepathpairs[j]]
		var p1 = nodepoints[onepathpairs[j+1]]
		var perp = Vector3(-(p1.y - p0.y), p1.x - p0.x, 0) if drawingtype != DRAWING_TYPE.DT_CENTRELINE else Vector3(-(p1.z - p0.z), 0, p1.x - p0.x)
		var fperp = linewidth*perp.normalized()
		var p0left = p0 - fperp
		var p0right = p0 + fperp
		var p1left = p1 - fperp
		var p1right = p1 + fperp
		surfaceTool.add_vertex(p0left)
		surfaceTool.add_vertex(p1left)
		surfaceTool.add_vertex(p0right)
		surfaceTool.add_vertex(p0right)
		surfaceTool.add_vertex(p1left)
		surfaceTool.add_vertex(p1right)
	surfaceTool.generate_normals()
	var newmesh = surfaceTool.commit()
	if $PathLines.mesh == null:
		$PathLines.mesh = newmesh
		var materialsystem = get_node("/root/Spatial/MaterialSystem")
		$PathLines.set_surface_material(0, materialsystem.pathlinematerial("centreline" if drawingtype == DRAWING_TYPE.DT_CENTRELINE else "normal"))
	else:
		var m = $PathLines.get_surface_material(0)
		$PathLines.mesh = newmesh
		$PathLines.set_surface_material(0, m)


func makexctubeshell(xcdrawings):
	var polys = Polynets.makexcdpolys(nodepoints, onepathpairs, true)
	if len(polys) == 2:
		return null
	var forepolyindexes = [ ]
	var backpolyindexes = [ ]
	for xctube in xctubesconn:
		if not xctube.positioningtube:
			var polyindex = xctube.pickedpolyindex0 if xctube.xcname0 == get_name() else xctube.pickedpolyindex1
			if polyindex != -1:
				var xcdrawingOther = xcdrawings.get_node(xctube.xcname1 if xctube.xcname0 == get_name() else xctube.xcname0)
				var ftubevec = xcdrawingOther.global_transform.origin - global_transform.origin
				if 	global_transform.basis.z.dot(ftubevec) > 0:
					forepolyindexes.append(polyindex)
				else:
					backpolyindexes.append(polyindex)
	
	var polypartial = null
	if forepolyindexes == [ len(polys)-1 ]:
		polypartial = backpolyindexes
	elif backpolyindexes == [ len(polys)-1 ]:
		polypartial = forepolyindexes
	else:
		return null
	
	var polyindexes = [ ]
	for i in range(len(polys)-1):
		if not polypartial.has(i):
			polyindexes.append(i)
	
	var arraymesh = ArrayMesh.new()
	var surfaceTool = SurfaceTool.new()
	#surfaceTool.set_material(Material.new())
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in polyindexes:
		var poly = polys[j]
		var pv = PoolVector2Array()
		for i in range(len(poly)):
			var p = poly[i]
			pv.append(Vector2(nodepoints[p].x, nodepoints[p].y))
		var pi = Geometry.triangulate_polygon(pv)
		for u in pi:
			#surfaceTool.add_vertex($XCnodes.get_node(poly[u]).global_transform.origin)
			surfaceTool.add_vertex($XCnodes.get_node(poly[u]).transform.origin)
	surfaceTool.generate_normals()
	surfaceTool.commit(arraymesh)
	return arraymesh
	
func updatexctubeshell(xcdrawings, makevisible):
	if makevisible:
		var xctubeshellmesh = makexctubeshell(xcdrawings)
		if xctubeshellmesh != null:
			if not has_node("XCflatshell"):
				var xcflatshell = preload("res://nodescenes/XCtubeshell.tscn").instance()
				xcflatshell.set_name("XCflatshell")
				xcflatshell.get_node("CollisionShape").shape = ConcavePolygonShape.new()
				add_child(xcflatshell)
			$XCflatshell/MeshInstance.mesh = xctubeshellmesh
			$XCflatshell/CollisionShape.shape.set_faces(xctubeshellmesh.get_faces())
			get_node("/root/Spatial/MaterialSystem").updatetubesectormaterial($XCflatshell, xcflatshellmaterial, false)
		else:
			if has_node("XCflatshell"):
				$XCflatshell.queue_free()
	elif has_node("XCflatshell"):
		$XCflatshell.visible = false
		$XCflatshell/CollisionShape.disabled = true
		

func xcdfullsetvisibilitycollision(bvisible):
	visible = bvisible
	if visible:
		$XCdrawingplane/CollisionShape.disabled = not $XCdrawingplane.visible
		if has_node("XCflatshell"):
			$XCflatshell/CollisionShape.disabled = not $XCflatshell.visible
	else:
		$XCdrawingplane/CollisionShape.disabled = true
		if has_node("XCflatshell"):
			$XCflatshell/CollisionShape.disabled = true
