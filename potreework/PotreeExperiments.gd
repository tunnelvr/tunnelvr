extends Spatial

var d = "/home/julian/data/pointclouds/potreetests/outdir/"

var metadata = null
var mdscale = Vector3(1,1,1)
var mdoffset = Vector3(0,0,0)
var nodestoload = [ ]
var fhierarchy = File.new()
var foctree = File.new()

func loadotree():
	var fmetadata = File.new()
	fmetadata.open(d+"metadata.json", File.READ)
	metadata = parse_json(fmetadata.get_as_text())
	mdoffset = Vector3(metadata["offset"][0], metadata["offset"][1], metadata["offset"][2])
	mdscale = Vector3(metadata["scale"][0], metadata["scale"][1], metadata["scale"][2])
	if not fhierarchy.is_open():
		fhierarchy.open(d+"hierarchy.bin", File.READ)
	assert(len(metadata["attributes"]) == 1)
	#metadata["attributes"], metadata["boundingBox"], mdoffset, mdscale

	var root = get_node("root")
	root.byteSize = metadata["hierarchy"]["firstChunkSize"]
	var mdmin = Vector3(metadata["boundingBox"]["min"][0], metadata["boundingBox"]["min"][1], metadata["boundingBox"]["min"][2])
	var mdmax = Vector3(metadata["boundingBox"]["max"][0], metadata["boundingBox"]["max"][1], metadata["boundingBox"]["max"][2])
	root.mesh.size = mdmax-mdmin
	root.transform.origin = (mdmax-mdmin)/2-mdoffset
	root.spacing = metadata["spacing"]
	var nodes = root.loadtreechunk(fhierarchy)
	
	for node in nodes:
		if not node.isnotloaded:
			nodestoload.append(node)


func _input(event):
	if event is InputEventKey and event.scancode == KEY_7 and event.pressed:
		loadotree()
	if event is InputEventKey and event.scancode == KEY_6 and event.pressed:
		if not foctree.is_open():
			foctree.open(d+"octree.bin", File.READ)
		for i in range(20):
			nodestoload[i].loadpoints(foctree, mdscale, mdoffset)
		
