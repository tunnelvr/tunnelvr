extends "res://potreework/Onode.gd"

var metadata = null
var mdscale = Vector3(1,1,1)
var mdoffset = Vector3(0,0,0)

var highlightplaneperp = Vector3(1,0,0)
var highlightplanedot = 0.0
	
var primarycameraorigin = Vector3(0,0,0)
var pointsizevisibilitycutoff = 15.0

var visiblepointcount = 0
var sweptvisiblepointcount = 0
var totalpointcount = 0
var otreecellscount = 0
var visiblepointcountLimit = 300000

var processingnode = null
var processingnodeWaitingForFile = false
var processingnodeReturnedFileHandle = null

var urlmetadata = ""
var urlhierarchy = ""
var urloctree = ""

var attributes_rgb_prebytes = -1
var attributes_postbytes = 0

onready var ImageSystem = get_node("/root/Spatial/ImageSystem")

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
			

func uppernodevisibilitymask(node, nodetobevisible):
	if node.visible != nodetobevisible:
		node.visible = nodetobevisible
		if node.visible:
			visiblepointcount += node.numPoints
		else:
			node.timestampatinvisibility = OS.get_ticks_msec()
			visiblepointcount -= node.numPoints
			updatenodeinvisibilitybelow(node)
			
		if node.treedepth >= 1:
			var pnode = node.get_parent()
			var nodebit = (1 << int(node.name))
			pnode.ocellmask |= nodebit
			if not node.visible:
				pnode.ocellmask ^= nodebit
			if pnode.pointmaterial != null:
				pnode.pointmaterial.set_shader_param("ocellmask", pnode.ocellmask)
			assert (((pnode.ocellmask & nodebit) != 0) == node.visible)

func updatenodeinvisibilitybelow(topnode):
	assert (not topnode.visible)
	if topnode.get_child_count() <= 1:
		return
	var node = topnode.get_child(1)
	var goingdown = true
	while true:
		if goingdown:
			if node.visible:
				node.visible = false
				var pnode = node.get_parent()
				var nodebit = (1 << int(node.name))
				pnode.ocellmask |= nodebit
				pnode.ocellmask ^= nodebit
				if pnode.pointmaterial != null:
					pnode.pointmaterial.set_shader_param("ocellmask", pnode.ocellmask)
				node.timestampatinvisibility = OS.get_ticks_msec()
				visiblepointcount -= node.numPoints
				if node.get_child_count() > 1:
					node = node.get_child(1)
				else:
					goingdown = false
			else:
				goingdown = false
		else:
			if node == topnode:
				break
			var inext = node.get_index() + 1
			var pnode = node.get_parent()
			if inext < pnode.get_child_count():
				node = pnode.get_child(inext)
				goingdown = true
			else:
				assert (node.ocellmask == 0)
				node = pnode


func freeinvisiblenoderesources(topnode):
	var node = topnode
	var goingdown = true
	while true:
		assert (!node.visible)
		if goingdown:
			if node.get_child_count() > 1:
				node = node.get_child(1)
			else:
				goingdown = false
		else:
			if node.pointmaterial != null:
				totalpointcount -= node.numPoints + node.numPointsCarriedDown
				node.mesh = null
				node.pointmaterial = null
			if node == topnode:
				break
			var inext = node.get_index() + 1
			node = node.get_parent()
			if inext < node.get_child_count():
				node = node.get_child(inext)
				goingdown = true
		

func garbagecollectionsweep():
	assert (processingnode == null)
	var node = self
	var oldestinvisiblenode = null
	while node != null:
		if node.treedepth >= 1 and node.name[0] != "h" and not node.visible and node.pointmaterial != null:
			if oldestinvisiblenode == null or node.timestampatinvisibility < oldestinvisiblenode.timestampatinvisibility:
				oldestinvisiblenode = node
		node = successornode(node, false)
	if oldestinvisiblenode != null:
		var oldestinvisiblenodeage = (OS.get_ticks_msec() - oldestinvisiblenode.timestampatinvisibility)/1000.0
		print("oldestinvisiblenodeage ", oldestinvisiblenodeage, " ", oldestinvisiblenode.get_child_count()-1)
		var prevtotalpointcount = totalpointcount
		freeinvisiblenoderesources(oldestinvisiblenode)
		print("totalpointcount was: ", prevtotalpointcount, " now: ", totalpointcount)
		
func constructpotreerootnode(lmetadata, lurlmetadata, bboffset):
	assert (name == "hroot")
	metadata = lmetadata
	visibleincamera = true
	visible = false
	cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	urlmetadata = lurlmetadata
	var urlotreedir = urlmetadata.substr(0, urlmetadata.find_last("/"))
	urlhierarchy = urlotreedir+"/hierarchy.bin"
	urloctree = urlotreedir+"/octree.bin"

	print("Forcing to centre bboffset", bboffset)
	mdoffset = Vector3(metadata["offset"][0], metadata["offset"][1], metadata["offset"][2])
	mdoffset -= bboffset

	mdscale = Vector3(metadata["scale"][0], metadata["scale"][1], metadata["scale"][2])
	var attributes_position_offset = -1
	var attributes_rgb_offset = -1
	var attributes_size = 0
	for attribute in metadata["attributes"]:
		if attribute["name"] == "position":
			attributes_position_offset = attributes_size
			assert (attribute["size"] == 12)
		elif attribute["name"] == "rgb":
			attributes_rgb_offset = attributes_size
			assert (attribute["size"] == 6)
		attributes_size += attribute.size
	assert (attributes_position_offset == 0)
	if attributes_rgb_offset == -1:
		attributes_rgb_prebytes = -1
		attributes_postbytes = attributes_size - 12
	else:
		attributes_rgb_prebytes = attributes_rgb_offset - 12
		attributes_postbytes = attributes_size - (attributes_rgb_offset + 6)
	
	hierarchybyteOffset = 0
	hierarchybyteSize = metadata["hierarchy"]["firstChunkSize"]
	var mdmin = Vector3(metadata["boundingBox"]["min"][0], metadata["boundingBox"]["min"][1], metadata["boundingBox"]["min"][2])
	var mdmax = Vector3(metadata["boundingBox"]["max"][0], metadata["boundingBox"]["max"][1], metadata["boundingBox"]["max"][2])
	mdmin -= bboffset
	mdmax -= bboffset

	ocellorigin = (mdmax + mdmin)/2
	spacing = metadata["spacing"]
	ocellsize = mdmax - mdmin
	transform.origin = ocellorigin

	Dboxmin = mdmin
	Dboxmax = mdmax
	print("yyy ", mdmin, mdmax)
	constructcontainingmesh()
