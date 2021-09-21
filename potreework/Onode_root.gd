extends "res://potreework/Onode.gd"

var metadata = null
var mdscale = Vector3(1,1,1)
var mdoffset = Vector3(0,0,0)
var pointsizefactor = 150.0
var fmetadata = File.new()
var fhierarchy = File.new()
var foctree = File.new()
var highlightplaneperp = Vector3(0,0,0)
var highlightplanedot = Vector3(0,0,0)

func loadotree(d, sname):
	assert (not fmetadata.is_open())
	name = "h"+sname
	fmetadata.open(d+"metadata.json", File.READ)
	fhierarchy.open(d+"hierarchy.bin", File.READ)
	foctree.open(d+"octree.bin", File.READ)

	metadata = parse_json(fmetadata.get_as_text())
	mdoffset = Vector3(metadata["offset"][0], 
					   metadata["offset"][1], 
					   metadata["offset"][2])
	
	mdscale = Vector3(metadata["scale"][0], 
					  metadata["scale"][1], 
					  metadata["scale"][2])

	assert(len(metadata["attributes"]) == 1)

	byteSize = metadata["hierarchy"]["firstChunkSize"]
	var mdmin = Vector3(metadata["boundingBox"]["min"][0], 
						metadata["boundingBox"]["min"][1], 
						metadata["boundingBox"]["min"][2])
	var mdmax = Vector3(metadata["boundingBox"]["max"][0], 
						metadata["boundingBox"]["max"][1], 
						metadata["boundingBox"]["max"][2])
	transform.origin = (mdmax+mdmin)/2
	spacing = metadata["spacing"]
	boxmin = mdmin
	boxmax = mdmax
	print("yyy ", boxmin, boxmax)
	constructcontainingmesh(mdmax-mdmin)

func sethighlightplane(lhighlightplaneperp, lhighlightplanedot):
	highlightplaneperp = lhighlightplaneperp
	highlightplanedot = lhighlightplanedot
	var nodestack = [ self ]
	while len(nodestack) != 0:
		var node = nodestack.pop_back()
		if node.pointmaterial != null:
			node.pointmaterial.set_shader_param("highlightplaneperp", highlightplaneperp)
			node.pointmaterial.set_shader_param("highlightplanedot", highlightplanedot)
			for cnode in node.get_children():
				if cnode.visible:
					nodestack.push_back(cnode)
				

func recalclodvisibility(cameraorigin):
	var nodestoload = [ ]
	if name[0] == "h" or pointmaterial == null:
		nodestoload.push_back(self)
	var nodestack = [ self ]
	while len(nodestack) != 0:
		var node = nodestack.pop_back()
		if node.pointmaterial != null:
			for cnode in node.get_children():
				if cnode.name == "visnote":
					continue
				if cnode.visibleincamera:
					var boxcentre = cnode.global_transform.origin
					var boxradius = ((cnode.boxmax - cnode.boxmin)/2).length()
					var cd = boxcentre.distance_to(cameraorigin)
					if cd <= boxradius + 0.1:
						cnode.visible = true
					else:
						var pointsize = pointsizefactor*cnode.spacing/(cd-boxradius)
						cnode.visible = (pointsize > 5)
					if cnode.visible:
						if cnode.name[0] == "h":
							nodestoload.push_back(cnode)
						elif cnode.pointmaterial == null:
							nodestoload.push_back(cnode)
							nodestack.push_back(cnode)
						else:
							nodestack.push_back(cnode)
				else:
					cnode.visible = false
	
	
	nodestack = [ self ]
	while len(nodestack) != 0:
		var node = nodestack.pop_back()
		if node.pointmaterial != null:
			node.setocellmask()
			for cnode in node.get_children():
				if cnode.visible:
					nodestack.push_back(cnode)
	return nodestoload
	
