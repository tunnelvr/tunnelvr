extends Spatial

#var d = "/home/julian/data/pointclouds/potreetests/outdir/"
# PotreeConverter --source xxx.laz --outdir outdir --attributes position_cartesian --method poisson
var d = "D:/potreetests/outdir/"

var metadata = null
var mdscale = Vector3(1,1,1)
var mdoffset = Vector3(0,0,0)
export var pointsizefactor = 50.0
var nodestoload = [ ]
var nodestopointload = [ ]
var nodespointloaded = [ ]
var fmetadata = File.new()
var fhierarchy = File.new()
var foctree = File.new()

func sethighlightplane(planetransform):
	for rnode in nodespointloaded:
		rnode.pointmaterial.set_shader_param("highlightplaneperp", planetransform.basis.z)
		rnode.pointmaterial.set_shader_param("highlightplanedot", planetransform.basis.z.dot(planetransform.origin))

func loadotree():
	assert (not fmetadata.is_open())
	fmetadata.open(d+"metadata.json", File.READ)
	metadata = parse_json(fmetadata.get_as_text())
	mdoffset = Vector3(metadata["offset"][0], metadata["offset"][2], -metadata["offset"][1])
	mdoffset = Vector3(-60,-10.1,50)
	mdscale = Vector3(metadata["scale"][0], metadata["scale"][2], metadata["scale"][1])
	if not fhierarchy.is_open():
		fhierarchy.open(d+"hierarchy.bin", File.READ)
	assert(len(metadata["attributes"]) == 1)
	#metadata["attributes"], metadata["boundingBox"], mdoffset, mdscale

	var root = get_node("root")
	root.loadrootdefinition(metadata, mdoffset)
	nodestoload.append(root)


func _input(event):
	if event is InputEventKey and event.scancode == KEY_7 and event.pressed:
		loadotree()
	if event is InputEventKey and event.scancode == KEY_6 and event.pressed:
		if len(nodestoload) != 0:
			var lnode = nodestoload.pop_front()
			var nodes = lnode.loadhierarchychunk(fhierarchy)
			for node in nodes:
				if not node.isdefinitionloaded:
					nodestoload.append(node)
				else:
					nodestopointload.append(node)
	if event is InputEventKey and event.scancode == KEY_5 and event.pressed:
		if not foctree.is_open():
			foctree.open(d+"octree.bin", File.READ)
		for i in range(0, 20):
			if len(nodestopointload) != 0:
				var rnode = nodestopointload.pop_front()
				rnode.loadoctcellpoints(foctree, mdscale, mdoffset, pointsizefactor)
				nodespointloaded.push_back(rnode)
