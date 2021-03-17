tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******
var regex = RegEx.new()

func _run():
	var fout = File.new()
	var fmeshname = "user://executingfeatures/mesh.txt"
	fout.open(fmeshname, File.READ)
	var x = parse_json(fout.get_line())
	fout.close()
	#print(x)

	var arraymesh = ArrayMesh.new()
	var surfaceTool = SurfaceTool.new()
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var v = x[0]
	for i in len(x[1]):
		var t = x[1][i]
		for j in range(3):
			var p = Vector2(v[t[j]][0], v[t[j]][1])
			surfaceTool.add_uv(p)
			surfaceTool.add_uv2(p)
			surfaceTool.add_vertex(Vector3(p.x, p.y, (int(i)%50)*0.005+0.005))
	surfaceTool.generate_normals()
	surfaceTool.commit(arraymesh)
	return arraymesh
	
