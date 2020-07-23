extends Spatial

var otxcdIndex0 : int
var otxcdIndex1 : int
var xcdrawinglink = [ ]  # [ nodepoints_ifrom0, nodepoints_ito0, nodepoints_ifrom1, nodepoints_ito1, ... ]
const linewidth = 0.02

func xcapplyonepath(xcn0, xcn1):
	for j in range(0, len(xcdrawinglink), 2):
		if xcdrawinglink[j] == xcn0.otIndex and xcdrawinglink[j+1] == xcn1.otIndex:
			xcdrawinglink.remove(xcn1.otIndex)
			xcdrawinglink.remove(xcn0.otIndex)
			xcn0 = null
			break
	if xcn0 != null:
		xcdrawinglink.append(xcn0.otIndex)
		xcdrawinglink.append(xcn1.otIndex)
	var xcdrawings = xcn1.get_parent().get_parent().get_parent()
	updatexclinkpaths(xcdrawings)

		
func updatexclinkpaths(xcdrawings):
	var surfaceTool = SurfaceTool.new()
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var xcdrawing0 = xcdrawings.get_child(otxcdIndex0)
	var xcdrawing1 = xcdrawings.get_child(otxcdIndex1)
	print("llll", xcdrawings, xcdrawing0, xcdrawing1)
	for j in range(0, len(xcdrawinglink), 2):
		#var p0 = xcdrawing0.nodepoints[xcdrawinglink[j]]
		#var p1 = xcdrawing1.nodepoints[xcdrawinglink[j+1]]
		var p0 = xcdrawing0.get_node("XCnodes").get_child(xcdrawinglink[j]).global_transform.origin
		var p1 = xcdrawing1.get_node("XCnodes").get_child(xcdrawinglink[j+1]).global_transform.origin
		print("jjjjuj", j, p0, p1)
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
	$PathLines.mesh = surfaceTool.commit()
	print("ususxxxxc ", len($PathLines.mesh.get_faces()), " ", len($PathLines.mesh.get_faces())) #surfaceTool.generate_normals()
	#updateworkingshell()
