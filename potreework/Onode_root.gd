extends "res://potreework/Onode.gd"

var metadata = null
var mdscale = Vector3(1,1,1)
var mdoffset = Vector3(0,0,0)
var pointsizefactor = 150.0

# pip install rangehttpserver
# python -m RangeHTTPServer (after editing site-packages/RangeHTTPServer/__main__.py line: SimpleHTTPServer.test(HandlerClass=RangeRequestHandler, bind="0.0.0.0")

var highlightplaneperp = Vector3(0,0,0)
var highlightplanedot = Vector3(0,0,0)

var primarycameraorigin = Vector3(0,0,0)
var pointsizevisibilitycutoff = 15.0

var visiblepointcount = 0
var totalpointcount = 0
var otreecellscount = 0
var visiblepointcountLimit = 500000

var processingnode = null
var processingnodeWaitingForFile = false
var processingnodeReturnedFileHandle = null

var urlmetadata = ""
var urlhierarchy = ""
var urloctree = ""

onready var ImageSystem = get_node("/root/Spatial/ImageSystem")

func commenceloadotree(urlotreedir):
	urlotreedir = "http://192.168.8.101:8000/"
	
	urlmetadata = urlotreedir+"metadata.json"
	urlhierarchy = urlotreedir+"hierarchy.bin"
	urloctree = urlotreedir+"octree.bin"
		
	ImageSystem.fetchrequesturl({ "url":urlmetadata, "callbackobject":self, "callbackfunction":"callbackloadotree" })

func callbackloadotree(fmetadata, nonimagedataobject):
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
	commenceocellprocessing()

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
		if node.visible:
			visiblepointcount += node.numPoints + node.numPointsCarriedDown
		else:
			node.timestampatinvisibility = OS.get_ticks_msec()
			visiblepointcount -= node.numPoints + node.numPointsCarriedDown
		
		if node.treedepth >= 1:
			var pnode = node.get_parent()
			var nodebit = (1 << int(node.name))
			pnode.ocellmask |= nodebit
			if not node.visible:
				pnode.ocellmask ^= nodebit
			if pnode.pointmaterial != null:
				pnode.pointmaterial.set_shader_param("ocellmask", pnode.ocellmask)
			assert (((pnode.ocellmask & nodebit) != 0) == node.visible)

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
		
func commenceocellprocessing():
	processingnode = self
	processingnodeWaitingForFile = false
	processingnodeReturnedFileHandle = null
	#ImageSystem.clearallpotreeactivity(self)
	print(" *** commenceocellprocessing")
	set_process(true)

var Dnonimagedataobject = null
var Dprocessingnode = null
func processingnodeWaitingEnded(f, nonimagedataobject):
	Dnonimagedataobject = nonimagedataobject
	Dprocessingnode = processingnode
	if processingnode != null:
		if processingnode.name[0] == "h":
			if nonimagedataobject["url"] == urlhierarchy and \
					nonimagedataobject["byteOffset"] == processingnode.hierarchybyteOffset and \
					nonimagedataobject["byteSize"] == processingnode.hierarchybyteSize:
				processingnodeReturnedFileHandle = f
			else:
				print("** discarding returning fetchrequesturl", nonimagedataobject)
		else:
			if nonimagedataobject["url"] == urloctree and \
					nonimagedataobject["byteOffset"] == processingnode.byteOffset and \
					nonimagedataobject["byteSize"] == processingnode.byteSize:
				processingnodeReturnedFileHandle = f
			else:
				print("** discarding returning fetchrequesturl", nonimagedataobject)
	
func _process(delta):
	if processingnode == null:
		print("  ** pointcount visible: ", visiblepointcount, "  all: ", totalpointcount, " otrees: ", otreecellscount)
		set_process(false)
		
	elif not processingnode.visibleincamera:
		uppernodevisibilitymask(processingnode, false)
		processingnode = successornode(processingnode, true)

	elif processingnode.name[0] == "h":
		if not processingnodeWaitingForFile:
			processingnodeWaitingForFile = true
			processingnodeReturnedFileHandle = null
			var nonimagedataobject = { "url":urlhierarchy, "callbackobject":self, 
									   "callbackfunction":"processingnodeWaitingEnded", 
									   "byteOffset":processingnode.hierarchybyteOffset, 
									   "byteSize":processingnode.hierarchybyteSize }
			ImageSystem.fetchrequesturl(nonimagedataobject)
		elif processingnodeReturnedFileHandle != null:
			processingnodeWaitingForFile = false
			var fhierarchyF = processingnodeReturnedFileHandle
			processingnodeReturnedFileHandle = null
			assert ((urlhierarchy.substr(0, 4) != "http") or (fhierarchyF.get_len() == processingnode.hierarchybyteSize))
			var nodesh = processingnode.loadhierarchychunk(fhierarchyF, get_parent().global_transform.inverse())
			for node in nodesh:
				if node.name[0] != "h":
					otreecellscount += 1
		
	else:
		if not processingnodeWaitingForFile:
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
				processingnodeWaitingForFile = true
				processingnodeReturnedFileHandle = null
				var nonimagedataobject = { "url":urloctree, "callbackobject":self, 
										   "callbackfunction":"processingnodeWaitingEnded", 
										   "byteOffset":processingnode.byteOffset, 
										   "byteSize":processingnode.byteSize }
				ImageSystem.fetchrequesturl(nonimagedataobject)
			else:
				processingnode = successornode(processingnode, not processingnode.visible)

		elif processingnodeReturnedFileHandle != null:
			processingnodeWaitingForFile = false
			var foctreeF = processingnodeReturnedFileHandle
			processingnodeReturnedFileHandle = null
			if (urloctree.substr(0, 4) == "http"):
				if (foctreeF.get_len() != processingnode.byteSize):
					print("lll ", foctreeF.get_len(), "  ", processingnode.byteSize)
			assert ((urloctree.substr(0, 4) != "http") or (foctreeF.get_len() == processingnode.byteSize))
			var roottransforminverse = get_parent().global_transform.inverse()
			processingnode.loadoctcellpoints(foctreeF, mdscale, mdoffset, pointsizefactor, roottransforminverse)
			totalpointcount += processingnode.numPoints + processingnode.numPointsCarriedDown
			processingnode = successornode(processingnode, not processingnode.visible)
