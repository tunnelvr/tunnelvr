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
var pointsizevisibilitycutoff = 10.0
var primarycameraorigin = Vector3(0,0,0)

func loadotree(d):
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

	hierarchybyteOffset = 0
	hierarchybyteSize = metadata["hierarchy"]["firstChunkSize"]
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
				

func successornode(node, skip):
	if not skip and node.get_child_count() > 1:
		return node.get_child(1)
	while true:
		if node.treedepth == 0:
			return null
		var inext = node.get_index() + 1
		node = node.get_parent()
		if inext < node.get_child_count():
			return node.get_child(inext)
			

var processingnode = null
func _process(delta):
	if processingnode == null:
		set_process(false)
		var nodestack = [ self ]
		while len(nodestack) != 0:
			var node = nodestack.pop_back()
			if node.pointmaterial != null:
				node.setocellmask()
				for cnode in node.get_children():
					if cnode.visible:
						nodestack.push_back(cnode)
		
		
	elif not processingnode.visibleincamera:
		processingnode.visible = false
		processingnode = successornode(processingnode, true)

	elif processingnode.name[0] == "h":
		processingnode.loadhierarchychunk(fhierarchy)
		
	else:
		var boxcentre = processingnode.global_transform.origin
		var boxradius = ((processingnode.boxmax - processingnode.boxmin)/2).length()
		var cd = boxcentre.distance_to(primarycameraorigin)
		if cd <= boxradius + 0.1:
			processingnode.visible = true
		else:
			var pointsize = pointsizefactor*processingnode.spacing/(cd-boxradius)
			processingnode.visible = (pointsize > pointsizevisibilitycutoff)
		
		if processingnode.visible and processingnode.pointmaterial == null:
			processingnode.loadoctcellpoints(foctree, mdscale, mdoffset, pointsizefactor)
		processingnode = successornode(processingnode, not processingnode.visible)


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
						cnode.visible = (pointsize > pointsizevisibilitycutoff)
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
	
