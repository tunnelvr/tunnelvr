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

var primarycameraorigin = Vector3(0,0,0)
var pointsizevisibilitycutoff = 10.0
var processingnode = null
var visiblepointcount = 0
var visiblepointcountLimit = 1000000

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
	ocellsize = mdmax - mdmin

	Dboxmin = mdmin
	Dboxmax = mdmax
	print("yyy ", mdmin, mdmax)
	constructcontainingmesh()

func sethighlightplane(lhighlightplaneperp, lhighlightplanedot):
	highlightplaneperp = lhighlightplaneperp
	highlightplanedot = lhighlightplanedot
	var node = self
	while node != null:
		if node.pointmaterial != null:
			node.pointmaterial.set_shader_param("highlightplaneperp", highlightplaneperp)
			node.pointmaterial.set_shader_param("highlightplanedot", highlightplanedot)
		node = successornode(node, not node.visible)

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
			

func uppernodevisibilitymask(node, lvisible):
	if node.visible != lvisible:
		node.visible = lvisible
		if not node.visible:
			node.timestampsinceinvisible = OS.get_ticks_msec()
			visiblepointcount -= node.numPoints
		else:
			visiblepointcount += node.numPoints
		
		if node.treedepth != 0:
			var pnode = node.get_parent()
			var nodebit = (1 << int(node.name))
			pnode.ocellmask |= nodebit
			if not node.visible:
				pnode.ocellmask ^= nodebit
			if pnode.pointmaterial != null:
				pnode.pointmaterial.set_shader_param("ocellmask", pnode.ocellmask)
			assert (((pnode.ocellmask & nodebit) != 0) == node.visible)


func commenceocellprocessing():
	processingnode = self
	set_process(true)

func _process(delta):
	if processingnode == null:
		set_process(false)
		
	elif not processingnode.visibleincamera:
		uppernodevisibilitymask(processingnode, false)
		processingnode = successornode(processingnode, true)

	elif processingnode.name[0] == "h":
		processingnode.loadhierarchychunk(fhierarchy)
		
	else:
		var boxcentre = processingnode.global_transform.origin
		var boxradius = (processingnode.ocellsize/2).length()
		var cd = boxcentre.distance_to(primarycameraorigin)
		var lvisible = true
		if cd > boxradius + 0.1:
			var pointsize = pointsizefactor*processingnode.spacing/(cd-boxradius)
			lvisible = (pointsize > pointsizevisibilitycutoff)
		if visiblepointcount > visiblepointcountLimit:
			lvisible = false
		uppernodevisibilitymask(processingnode, lvisible)
		
		if processingnode.visible and processingnode.pointmaterial == null:
			processingnode.loadoctcellpoints(foctree, mdscale, mdoffset, pointsizefactor)
		processingnode = successornode(processingnode, not processingnode.visible)


