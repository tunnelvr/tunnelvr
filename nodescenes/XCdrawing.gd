extends Spatial

	
const XCnode = preload("res://nodescenes/XCnode.tscn")
const linewidth = 0.05
var otxcdIndex: int = 0

var nodepoints = [ ]	# : = PoolVector3Array() 
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
	#nodepoints[xcn.otIndex] = xcn.global_transform.origin
	nodepoints[xcn.otIndex] = xcn.translation

func copyotnodetoxcn(xcn):
	#xcn.global_transform.origin = nodepoints[xcn.otIndex]
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
	if removeotnodepoint(xcn.otIndex):
		copyotnodetoxcn($XCnodes.get_child(xcn.otIndex))
	$XCnodes.get_child($XCnodes.get_child_count()-1).free()
	updatexcpaths()

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
	
