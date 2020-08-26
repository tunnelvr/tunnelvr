extends Spatial

const XCnode = preload("res://nodescenes/XCnode.tscn")
const XCnode_centreline = preload("res://nodescenes/XCnode_centreline.tscn")

# primary data
var xcname = ""         # must match what is in the godot and used for the names in xctube
var xcresource = ""     # source file
var nodepoints = { }    # { nodename:Vector3 }
var onepathpairs = [ ]  # [ Anodename0, Anodename1, Bnodename0, Bnodename1, ... ]
var drawingtype = DRAWING_TYPE.DT_XCDRAWING


# derived data
var xctubesconn = [ ]   # references to xctubes that connect to here (could use their names instead)
var maxnodepointnumber = 0

const linewidth = 0.05

remotesync func setxcdrawingvisibility(makevisible):
	if not makevisible:
		$XCdrawingplane.visible = false
		$XCdrawingplane/CollisionShape.disabled = true
	elif makevisible != $XCdrawingplane.visible:
		$XCdrawingplane.visible = true
		$XCdrawingplane/CollisionShape.disabled = false
		if drawingtype == DRAWING_TYPE.DT_XCDRAWING:
			var sca = 1.0
			for nodepoint in nodepoints.values():
				sca = max(sca, abs(nodepoint.x) + 1)
				sca = max(sca, abs(nodepoint.y) + 1)
			if sca > $XCdrawingplane.scale.x:
				$XCdrawingplane.set_scale(Vector3(sca, sca, 1.0))

# these transforming operations work in sequence, each correcting the relative position change caused by the other
func scalexcnodepointspointsxy(scax, scay):
	for i in nodepoints.keys():
		nodepoints[i] = Vector3(nodepoints[i].x*scax, nodepoints[i].y*scay, nodepoints[i].z)
		copyotnodetoxcn($XCnodes.get_node(i))

func setxcpositionangle(drawingwallangle):
	global_transform = Transform(Basis().rotated(Vector3(0,-1,0), drawingwallangle), global_transform.origin)

func setxcpositionorigin(pt0):
	global_transform.origin = Vector3(pt0.x, 0, pt0.z)

remote func setxcdrawingposition(lglobal_transform):
	global_transform = lglobal_transform

func exportxcdata():
	var nodepointsData = [ ]
	for i in nodepoints.keys():
		nodepointsData.append(i)
		nodepointsData.append(nodepoints[i].x)
		nodepointsData.append(nodepoints[i].y)
		nodepointsData.append(nodepoints[i].z)
	return { "name":get_name(),  # defines the image
			 "drawingtype":drawingtype,
			 "transformpos":var2str(global_transform),
			 "shapeimage":[$XCdrawingplane.scale.x, $XCdrawingplane.scale.y],
			 "nodepoints": nodepointsData, 
			 "onepathpairs":onepathpairs,
			 "visible":$XCdrawingplane.visible 
		   }

func exportxcrpcdata():
	return [ get_name(), drawingtype, global_transform, maxnodepointnumber, 
			 $XCdrawingplane.scale.x, $XCdrawingplane.scale.y,
			 nodepoints, onepathpairs, $XCdrawingplane.visible ]

func mergexcrpcdata(xcdata):
	assert ((get_name() == xcdata[0]) and (drawingtype == xcdata[1]))
	global_transform = xcdata[2]
	maxnodepointnumber = xcdata[3]
	$XCdrawingplane.scale = Vector3(xcdata[4], xcdata[5], 1.0)
	nodepoints = xcdata[6]
	onepathpairs = xcdata[7]
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
	setxcdrawingvisibility(xcdata[8])
		
func importxcdata(xcdrawingData):
	assert ($XCnodes.get_child_count() == 0 and len(nodepoints) == 0 and len(xctubesconn) == 0)
	drawingtype = int(xcdrawingData["drawingtype"])
	$XCdrawingplane.set_scale(Vector3(xcdrawingData["shapeimage"][0], xcdrawingData["shapeimage"][1], 1.0))
	global_transform = str2var(xcdrawingData["transformpos"])
	var nodepointsData = xcdrawingData["nodepoints"]
	for i in range(len(nodepointsData)/4):
		var k = nodepointsData[i*4]
		nodepoints[k] = Vector3(nodepointsData[i*4+1], nodepointsData[i*4+2], nodepointsData[i*4+3])
		var xcn = XCnode_centreline.instance() if drawingtype == DRAWING_TYPE.DT_CENTRELINE else XCnode.instance()
		$XCnodes.add_child(xcn)
		xcn.set_name(k)
		xcn.translation = nodepoints[k]
		maxnodepointnumber = max(maxnodepointnumber, int(k))
	onepathpairs = xcdrawingData["onepathpairs"]
	updatexcpaths()
	setxcdrawingvisibility(xcdrawingData["visible"])


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
			var xcdata = [ 	xcdrawingSect1.get_name(), DRAWING_TYPE.DT_XCDRAWING, 
							Transform(Basis().rotated(Vector3(0,-1,0), ang), p), 0, 
							max(xsectlruds[i*4], xsectlruds[i*4+1])+1, max(xsectlruds[i*4+2], xsectlruds[i*4+3])+1, 
							hexnodepoints, hexonepathpairs.duplicate(), false ]
			xcdrawingSect1.mergexcrpcdata(xcdata)
			if xcdrawingSect != null:
				var xctube = sketchsystem.newXCtube(xcdrawingSect, xcdrawingSect1)
				xctube.xcdrawinglink = ["hl", "hl", "hr", "hr"].duplicate()
				xctube.updatetubelinkpaths(sketchsystem)
			xcdrawingSect = xcdrawingSect1


func duplicatexcdrawing(sketchsystem):
	var xcdrawing = sketchsystem.newXCuniquedrawing(DRAWING_TYPE.DT_XCDRAWING, sketchsystem.uniqueXCname())
	
	xcdrawing.global_transform = global_transform
	for i in nodepoints.keys():
		var xcn = xcdrawing.newxcnode(i)
		xcdrawing.nodepoints[i] = nodepoints[i]
		copyotnodetoxcn(xcn)
	xcdrawing.onepathpairs = onepathpairs.duplicate()
	xcdrawing.updatexcpaths()
	return xcdrawing
	
func copyxcntootnode(xcn):
	nodepoints[xcn.get_name()] = xcn.translation
	
func copyotnodetoxcn(xcn):
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
	xcn.global_transform.origin = pt
	copyxcntootnode(xcn)
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
		sketchsystem.rpc("xcdrawingfromdata", sketchsystem.get_node("XCdrawings").get_node(xcdrawingname).exportxcrpcdata())
	for xctube in xctubesconnupdated:
		xctube.updatetubelinkpaths(sketchsystem)
		sketchsystem.rpc("xctubefromdata", xctube.exportxctrpcdata())

func updatexcpaths(llinewidth=0):
	var xcembeddedtype = (llinewidth==0)
	if drawingtype == DRAWING_TYPE.DT_PAPERTEXTURE and llinewidth == 0:
		return
	if len(onepathpairs) == 0:
		$PathLines.mesh = null
		return
		
	if llinewidth == 0:
		llinewidth = linewidth*0.7 if drawingtype == DRAWING_TYPE.DT_CENTRELINE else linewidth
	var surfaceTool = SurfaceTool.new()
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in range(0, len(onepathpairs), 2):
		var p0 = nodepoints[onepathpairs[j]]
		var p1 = nodepoints[onepathpairs[j+1]]
		var perp = Vector3(-(p1.y - p0.y), p1.x - p0.x, 0) if xcembeddedtype else Vector3(-(p1.z - p0.z), 0, p1.x - p0.x)
		var fperp = llinewidth*perp.normalized()
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
	var mustsetmaterial = ($PathLines.mesh == null)
	var m = $PathLines.get_surface_material(0)
	$PathLines.mesh = surfaceTool.commit()
	$PathLines.set_surface_material(0, m)
	if mustsetmaterial:
		m = load("res://guimaterials/XCdrawingCentrelines.material") if drawingtype == DRAWING_TYPE.DT_CENTRELINE else load("res://guimaterials/XCdrawingPathlines.material")
	$PathLines.set_surface_material(0, m)
	
func sd0(a, b):
	return a[0] < b[0]

func makexcdpolys(discardsinglenodepaths):
	var Lpathvectorseq = { } 
	for i in nodepoints.keys():
		Lpathvectorseq[i] = []  # [ (arg, pathindex) ]
	var Npaths = len(onepathpairs)/2
	var opvisits2 = [ ]
	for i in range(Npaths):
		var i0 = onepathpairs[i*2]
		var i1 = onepathpairs[i*2+1]
		var vec3 = nodepoints[i1] - nodepoints[i0]
		var vec = Vector2(vec3.x, vec3.y)
		Lpathvectorseq[i0].append([vec.angle(), i])
		Lpathvectorseq[i1].append([(-vec).angle(), i])
		opvisits2.append(0)
		opvisits2.append(0)
		
	for pathvectorseq in Lpathvectorseq.values():
		pathvectorseq.sort_custom(self, "sd0")
		
	var polys = [ ]
	var outerpoly = null
	assert (len(opvisits2) == len(onepathpairs))
	for i in range(len(opvisits2)):
		if opvisits2[i] != 0:
			continue
		var ne = int(i/2)
		var np = onepathpairs[ne*2 + (0 if ((i%2)==0) else 1)]
		var poly = [ ]
		var Nsinglenodes = 0
		while (opvisits2[ne*2 + (0 if onepathpairs[ne*2] == np else 1)]) == 0:
			opvisits2[ne*2 + (0 if onepathpairs[ne*2] == np else 1)] = len(polys)+1
			poly.append(np)
			np = onepathpairs[ne*2 + (1  if onepathpairs[ne*2] == np  else 0)]
			if len(Lpathvectorseq[np]) == 1:
				Nsinglenodes += 1
			for j in range(len(Lpathvectorseq[np])):
				if Lpathvectorseq[np][j][1] == ne:
					ne = Lpathvectorseq[np][(j+1)%len(Lpathvectorseq[np])][1]
					break
		
		# find and record the orientation of the polygon by looking at the bottom left
		var jbl = 0
		var ptbl = nodepoints[poly[jbl]]
		for j in range(1, len(poly)):
			var pt = nodepoints[poly[j]]
			if pt.y < ptbl.y or (pt.y == ptbl.y and pt.x < ptbl.x):
				jbl = j
				ptbl = pt
		var ptblFore = nodepoints[poly[(jbl+1)%len(poly)]]
		var ptblBack = nodepoints[poly[(jbl+len(poly)-1)%len(poly)]]
		var angFore = Vector2(ptblFore.x-ptbl.x, ptblFore.y-ptbl.y).angle()
		var angBack = Vector2(ptblBack.x-ptbl.x, ptblBack.y-ptbl.y).angle()
		
		# add in the trailing two settings into the poly array
		if Nsinglenodes == 0 or not discardsinglenodepaths:
			if not (angBack < angFore):
				if outerpoly != null:
					print(" *** extra outer poly ", outerpoly, poly)
					polys.append(outerpoly) 
				outerpoly = poly
			else:
				polys.append(poly)
	polys.append(outerpoly if outerpoly != null else [])
	return polys

func makexctubeshell(xcdrawings):
	var polys = makexcdpolys(true)
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
	var materialdirt = preload("res://lightweighttextures/simpledirt.material")
	surfaceTool.set_material(materialdirt)
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
				add_child(xcflatshell)
			$XCflatshell/MeshInstance.mesh = xctubeshellmesh
			var materialdirt = preload("res://lightweighttextures/simpledirt.material")
			for i in range($XCflatshell/MeshInstance.get_surface_material_count()):
				$XCflatshell/MeshInstance.set_surface_material(i, materialdirt)
			$XCflatshell/CollisionShape.shape.set_faces(xctubeshellmesh.get_faces())
			$XCflatshell.visible = true
			$XCflatshell/CollisionShape.disabled = false
		else:
			if has_node("XCflatshell"):
				$XCflatshell.queue_free()
	elif has_node("XCflatshell"):
		$XCflatshell.visible = false
		$XCflatshell/CollisionShape.disabled = true
		

