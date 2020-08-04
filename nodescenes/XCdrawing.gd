extends Spatial

const XCnode = preload("res://nodescenes/XCnode.tscn")

const linewidth = 0.05
var otxcdIndex: int = 0

var nodepoints = [ ]    # list of Vector3
var onepathpairs = [ ]  # sequence of pairs indexing the nodepoints
var xctubesconn = [ ]   # references to xctubes that connect to here (could use their names instead)

var floortype = false

func setxcdrawingvisibility(makevisible):
	if not makevisible:
		$XCdrawingplane.visible = false
		$XCdrawingplane/CollisionShape.disabled = true
	elif makevisible != $XCdrawingplane.visible:
		$XCdrawingplane.visible = true
		$XCdrawingplane/CollisionShape.disabled = false
		var sca = 1.0
		for nodepoint in nodepoints:
			sca = max(sca, abs(nodepoint.x) + 1)
			sca = max(sca, abs(nodepoint.y) + 1)
		if sca > $XCdrawingplane.scale.x:
			$XCdrawingplane.set_scale(Vector3(sca, sca, 1.0))


# these transforming operations work in sequence, each correcting the relative position change caused by the other
func scalexcnodepointspointsx(sca):
	for i in range(len(nodepoints)):
		nodepoints[i] = Vector3(nodepoints[i].x*sca, nodepoints[i].y, nodepoints[i].z)
		copyotnodetoxcn($XCnodes.get_child(i))

func setxcpositionangle(drawingwallangle):
	global_transform = Transform(Basis().rotated(Vector3(0,-1,0), drawingwallangle), global_transform.origin)

func setxcpositionorigin(pt0):
	global_transform.origin = Vector3(pt0.x, 0, pt0.z)

func exportdata():
	var nodepointsData = [ ]
	for i in range(len(nodepoints)):
		nodepointsData.append(nodepoints[i].x)
		nodepointsData.append(nodepoints[i].y)
		nodepointsData.append(nodepoints[i].z)
	var xvec = Vector2(global_transform.basis.x.x, global_transform.basis.x.z)
	return { "name":get_name(),
			 "transpos": [xvec.angle(), $XCdrawingplane.scale.x, global_transform.origin.x, global_transform.origin.y, global_transform.origin.z], 
			 "nodepoints": nodepointsData, 
			 "onepathpairs":onepathpairs 
		   }

func importdata(xcdrawingData):
	var transpos = xcdrawingData["transpos"]
	$XCdrawingplane.set_scale(Vector3(transpos[1], transpos[1], 1.0))
	if floortype:
		rotate_y(transpos[0])
	else:
		setxcpositionangle(transpos[0])
	global_transform.origin = Vector3(transpos[2], transpos[3], transpos[4])

	var nodepointsData = xcdrawingData["nodepoints"]
	for i in range(0, len(nodepointsData), 3):
		nodepoints.append(Vector3(nodepointsData[i], nodepointsData[i+1], nodepointsData[i+2]))
	
	for xcn in $XCnodes.get_children():
		xcn.free()
	nodepoints.clear()
	for i in range(len(nodepointsData)/3):
		nodepoints.append(Vector3(nodepointsData[i*3], nodepointsData[i*3+1], nodepointsData[i*3+2]))
		var xcn = XCnode.instance()
		xcn.otIndex = i
		$XCnodes.add_child(xcn)
		xcn.set_name("XCnode"+String(xcn.otIndex))  # We could use to_int on this to abolish need for otIndex
		xcn.translation = nodepoints[xcn.otIndex]
			
	onepathpairs = xcdrawingData["onepathpairs"]
	for i in range(len(onepathpairs)):
		onepathpairs[i] = int(onepathpairs[i])    # parse_json brings all ints back as floats!
	xctubesconn.clear()
	updatexcpaths()

func duplicatexcdrawing(sketchsystem):
	var XCdrawing = load("res://nodescenes/XCdrawing.tscn")  # self-instance
	var xcdrawing = XCdrawing.instance()
	var otxcdIndex = sketchsystem.get_node("XCdrawings").get_child_count()
	xcdrawing.set_name("XCdrawing"+String(otxcdIndex))
	xcdrawing.otxcdIndex = otxcdIndex
	sketchsystem.get_node("XCdrawings").add_child(xcdrawing)
	xcdrawing.global_transform = global_transform
	for i in range(len(nodepoints)):
		var xcn = xcdrawing.newxcnode(-1)
		xcdrawing.nodepoints[i] = nodepoints[i]
		copyotnodetoxcn(xcn)
	xcdrawing.onepathpairs = onepathpairs.duplicate()
	xcdrawing.updatexcpaths()
	return xcdrawing
	
func removeotnodepoint(i, brejoinlines):
	var e = len(nodepoints) - 1
	nodepoints[i] = nodepoints[e]
	nodepoints.resize(e)
	var rejoinnodes = [ ]
	for j in range(len(onepathpairs) - 2, -1, -2):
		if (onepathpairs[j] == i) or (onepathpairs[j+1] == i):
			rejoinnodes.append(onepathpairs[j+1]  if onepathpairs[j] == i  else onepathpairs[j])
			onepathpairs[j] = onepathpairs[-2]
			onepathpairs[j+1] = onepathpairs[-1]
			onepathpairs.resize(len(onepathpairs) - 2)
		else:
			if onepathpairs[j] == e:
				onepathpairs[j] = i
			if onepathpairs[j+1] == e:
				onepathpairs[j+1] = i
	print("brejoinlinesbrejoinlinesbrejoinlinesbrejoinlines ", brejoinlines, " ", rejoinnodes)
	if brejoinlines and len(rejoinnodes) >= 2:
		onepathpairs.append(i if rejoinnodes[0] == e else rejoinnodes[0])
		onepathpairs.append(i if rejoinnodes[1] == e else rejoinnodes[1])
	return i != e
	
func copyxcntootnode(xcn):
	nodepoints[xcn.otIndex] = xcn.translation

func copyotnodetoxcn(xcn):
	xcn.translation = nodepoints[xcn.otIndex]

func xcotapplyonepath(i0, i1):
	for j in range(len(onepathpairs)-2, -3, -2):
		if j == -2:
			print("addingonepath ", len(onepathpairs))
			onepathpairs.push_back(i0)
			onepathpairs.push_back(i1)
		elif (onepathpairs[j] == i0 and onepathpairs[j+1] == i1) or (onepathpairs[j] == i1 and onepathpairs[j+1] == i0):
			onepathpairs[j] = onepathpairs[-2]
			onepathpairs[j+1] = onepathpairs[-1]
			onepathpairs.resize(len(onepathpairs) - 2)
			print("deletedonepath ", j)
			break

func newxcnode(lotIndex):
	var xcn = XCnode.instance()
	$XCnodes.add_child(xcn)
	if lotIndex == -1:
		nodepoints.push_back(Vector3())
		xcn.otIndex = len(nodepoints) - 1
	else:
		xcn.otIndex = lotIndex
	xcn.set_name("XCnode"+String(xcn.otIndex))  # We could use to_int on this to abolish need for otIndex
	return xcn

func removexcnode(xcn, brejoinlines, sketchsystem):
	var xcnIndex = xcn.otIndex
	if removeotnodepoint(xcnIndex, brejoinlines):
		copyotnodetoxcn($XCnodes.get_child(xcnIndex))
	$XCnodes.get_child($XCnodes.get_child_count()-1).free()
	for xctube in xctubesconn:
		xctube.removetubenodepoint(otxcdIndex, xcnIndex, len(nodepoints))
	updatexcpaths()
	for xctube in xctubesconn:
		xctube.updatetubelinkpaths(sketchsystem.get_node("XCdrawings"), sketchsystem)

func movexcnode(xcn, pt, sketchsystem):
	print("m,mmmmxmxmxm ", xcn.global_transform.origin, pt)
	xcn.global_transform.origin = pt
	copyxcntootnode(xcn)
	updatexcpaths()
	for xctube in xctubesconn:
		xctube.updatetubelinkpaths(sketchsystem.get_node("XCdrawings"), sketchsystem)

func updatexcpaths():
	print("iupdatingxxccpaths ", len(onepathpairs))
	var prevsurfacematerial = $PathLines.get_surface_material(0)
	var surfaceTool = SurfaceTool.new()
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in range(0, len(onepathpairs), 2):
		var p0 = nodepoints[onepathpairs[j]]
		var p1 = nodepoints[onepathpairs[j+1]]
		var perp = linewidth*Vector2(-(p1.y - p0.y), p1.x - p0.x).normalized()
		var p0left = p0 - Vector3(perp.x, perp.y, 0)
		var p0right = p0 + Vector3(perp.x, perp.y, 0)
		var p1left = p1 - Vector3(perp.x, perp.y, 0)
		var p1right = p1 + Vector3(perp.x, perp.y, 0)
		surfaceTool.add_vertex(p0left)
		surfaceTool.add_vertex(p1left)
		surfaceTool.add_vertex(p0right)
		surfaceTool.add_vertex(p0right)
		surfaceTool.add_vertex(p1left)
		surfaceTool.add_vertex(p1right)
	surfaceTool.generate_normals()
	$PathLines.mesh = surfaceTool.commit()
	print("usus ", len($PathLines.mesh.get_faces()), " ", len($PathLines.mesh.get_faces())) #surfaceTool.generate_normals()
	#updateworkingshell()
	$PathLines.set_surface_material(0, prevsurfacematerial if prevsurfacematerial != null else load("res://guimaterials/XCdrawingPathlines.material"))

func sd0(a, b):
	return a[0] < b[0]

func makexcdpolys():
	var Lpathvectorseq = [ ] 
	for _i in range(len(nodepoints)):
		Lpathvectorseq.append([])  # [ (arg, pathindex) ]
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
		
	for pathvectorseq in Lpathvectorseq:
		pathvectorseq.sort_custom(self, "sd0")
		
	var polys = [ ]
	for i in range(len(opvisits2)):
		if opvisits2[i] != 0:
			continue
		# warning-ignore:integer_division
		var ne = (i/2)
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
		poly.append(1000+Nsinglenodes)
		poly.append(angBack < angFore)
		polys.append(poly)

	return polys

func makexcdworkingshell():
	var polys = makexcdpolys()  # arrays of indexes to nodes ending with [Nsinglenodes, orientation]
	var surfaceTool = SurfaceTool.new()
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for poly in polys:
		if len(poly) <= 4 or poly[-2] != 1000 or poly[-1] == false:
			continue
		var pv = PoolVector2Array()
		for i in range(len(poly)-2):
			var p = poly[i]
			pv.append(Vector2(nodepoints[p].x, nodepoints[p].y))
		var pi = Geometry.triangulate_polygon(pv)
		for u in pi:
			surfaceTool.add_vertex($XCnodes.get_child(poly[u]).global_transform.origin + global_transform.basis.z*0.002)
	surfaceTool.generate_normals()
	return surfaceTool.commit()

