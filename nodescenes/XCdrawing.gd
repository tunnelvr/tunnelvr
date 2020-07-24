extends Spatial

const XCnode = preload("res://nodescenes/XCnode.tscn")
const linewidth = 0.05
var otxcdIndex: int = 0

var nodepoints = [ ]    # : = PoolVector3Array() 
var onepathpairs = [ ]  # : = PoolIntArray()  # 2* pairs indexing into nodepoints
var xctubesconn = [ ]

func newotnodepoint():
	nodepoints.push_back(Vector3())
	return len(nodepoints) - 1

func removeotnodepoint(i):
	var e = len(nodepoints) - 1
	nodepoints[i] = nodepoints[e]
	nodepoints.resize(e)
	for j in range(len(onepathpairs) - 2, -1, -2):
		if (onepathpairs[j] == i) or (onepathpairs[j+1] == i):
			onepathpairs[j] = onepathpairs[-2]
			onepathpairs[j+1] = onepathpairs[-1]
			onepathpairs.resize(len(onepathpairs) - 2)
		else:
			if onepathpairs[j] == e:
				onepathpairs[j] = i
			if onepathpairs[j+1] == e:
				onepathpairs[j+1] = i
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
		xcn.otIndex = newotnodepoint()
	else:
		xcn.otIndex = lotIndex
	return xcn

func removexcnode(xcn):
	var xcnIndex = xcn.otIndex
	if removeotnodepoint(xcnIndex):
		copyotnodetoxcn($XCnodes.get_child(xcnIndex))
	$XCnodes.get_child($XCnodes.get_child_count()-1).free()
	for xctube in xctubesconn:
		xctube.removetubenodepoint(otxcdIndex, xcnIndex, len(nodepoints))
	updatexcpaths()
	for xctube in xctubesconn:
		xctube.updatexclinkpaths(get_parent())

func movexcnode(xcn, pt):
	xcn.global_transform.origin = pt
	copyxcntootnode(xcn)
	updatexcpaths()
	for xctube in xctubesconn:
		xctube.updatexclinkpaths(get_parent())

func updatexcpaths():
	print("iupdatingxxccpaths ", len(onepathpairs))
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


func sd0(a, b):
	return a[0] < b[0]

func makexcdpolys():
	var Lpathvectorseq = [ ] 
	for i in range(len(nodepoints)):
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
		print(pathvectorseq)
		
	var polys = [ ]
	for i in range(len(opvisits2)):
		if opvisits2[i] != 0:
			continue
		# warning-ignore:integer_division
		var ne = (i/2)
		print("iiii", i)
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
		print("AnglesAAA should be <180 ", [angFore, angBack])
		
		# add in the trailing two settings into the poly array
		poly.append(1000+Nsinglenodes)
		poly.append(angBack < angFore)
		print("pppp ", len(poly), " ", poly)
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
		print("piiii", pi)
		for u in pi:
			surfaceTool.add_vertex($XCnodes.get_child(poly[u]).global_transform.origin + global_transform.basis.z*0.002)
	surfaceTool.generate_normals()
	return surfaceTool.commit()

