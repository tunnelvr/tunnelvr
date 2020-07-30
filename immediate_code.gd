tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******

const CentrelineStationNode = preload("res://nodescenes/StationNode.tscn")

func _ready():
	print("jjo")
	
func fa(a, b):
	
	print(a, b)
	return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1])
	
	
func _run():
	print([10,20,30,40].find(30))   # gives 2
	print(parse_json(to_json([10,20,30,40])).find(30))  # gives -1
	print("jj")
	
	# In Javascript
	JSON.parse(JSON.stringify([10,20,30,40])).indexOf(30)  # gives 2

	# In Python
	json.loads(json.dumps([10,20,30,40])).index(30)   # gives 2

	var a = [10,20,30,40]
	var b = parse_json(to_json(a))
	print("a is ", a)
	print("a.find(30) gives ", a.find(30))
	print("b is ", a)
	print("b.find(30) gives ", b.find(30), " even though b[2]==30 is ", b[2]==30)
	
	var typeslookup = { TYPE_INT:"int", TYPE_REAL:"float"}
	print("a[2] is ", typeslookup[typeof(a[2])])
	print("b[2] is ", typeslookup[typeof(b[2])])

	print(int(9))
	print(b[2])

	
func D_run():
	# get all the connections in here between the polygons but in the right order
	var poly0 = [1, 0, 2]
	var poly1 = [1, 0, 5, 4, 3, 2]
	var xcdrawinglink = [ 2, 5 ]

	var ila = [ ]  # [ [ il0, il1 ] ]
	for j in range(0, len(xcdrawinglink), 2):
		var il0 = poly0.find(xcdrawinglink[j])
		var il1 = poly1.find(xcdrawinglink[j+1])
		if il0 != -1 and il1 != -1:
			ila.append([il0, il1])
	ila.sort_custom(self, "fa")
	print("ilililia", ila)
	
	var surfaceTool = SurfaceTool.new()
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(len(ila)):
		var ila0 = ila[i][0]
		var ila0N = ila[i+1][0] - ila0  if i < len(ila)-1  else len(poly0) + ila[0][0] - ila0 
		var ila1 = ila[i][1]
		var ila1N = ila[(i+1)%len(ila)][1] - ila1
		if ila1N < 0 or len(ila) == 1:   # there's a V-shaped case where this isn't good enough
			ila1N += len(poly1)
		print("  iiilla ", [[ila0, ila0N], [ila1, ila1N]])
		
		var acc = -ila0N/2  if ila0N>=ila1N  else  ila1N/2
		var i0 = 0
		var i1 = 0
		while i0 < ila0N or i1 < ila1N:
			if acc < 0:
				acc += ila1N
				i0 += 1
			else:
				acc -= ila0N
				i1 += 1
			print(i0, " ", i1, "  acc ", acc)
		
		
