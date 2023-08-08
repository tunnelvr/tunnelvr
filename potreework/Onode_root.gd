extends "res://potreework/Onode.gd"

var metadata = null
var mdscale = Vector3(1,1,1)
var mdoffset = Vector3(0,0,0)

var highlightzonetransform = Transform()
var slicedisappearthickness = 0.0

var highlightdist = 0.5
var highlightcol = Vector3(1,1,0)
var highlightcol2 = Vector3(0,1,1)
	
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

func sethighlighttransformR(lhighlightzonetransform):
	if lhighlightzonetransform == null:
		slicedisappearthickness = 0.0
	elif Tglobal.housahedronmode:
		highlightzonetransform = lhighlightzonetransform
		slicedisappearthickness = 0.25
	else:
		highlightzonetransform = lhighlightzonetransform
		slicedisappearthickness = 1000.0
	var node = self
	while node != null:
		if node.pointmaterial != null:
			node.pointmaterial.set_shader_param("highlightzonetransform", highlightzonetransform)
			node.pointmaterial.set_shader_param("slicedisappearthickness", slicedisappearthickness)
		node = successornode(node, not node.visible)
	
func successornode(node, skip):
	if not skip and node.get_child_count() > 0:
		return node.get_child(0)
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
	if topnode.get_child_count() == 0:
		return
	var node = topnode.get_child(0)
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
				if node.get_child_count() > 0:
					node = node.get_child(0)
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
			if node.get_child_count() != 0:
				node = node.get_child(0)
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

	if Tglobal.housahedronmode:
		highlightdist = 0.15
		highlightcol = Vector3(0.8,0.0,0.8)
		highlightcol2 = Vector3(0.8,0.0,0.8)
	else:
		highlightdist = 0.5
		highlightcol = Vector3(1,1,0)
		highlightcol2 = Vector3(0,1,1)

	constructcontainingmesh()

func completedocellpointsmesh(onoderequest):
	var nnode = onoderequest["nnode"]
	print(" ---- completedocellpointsmeshcompletedocellpointsmeshcompletedocellpointsmesh ", onoderequest.get("pointmesh"), nnode.name)
	if onoderequest.get("pointmesh") != null:
		nnode.mesh = onoderequest["pointmesh"]
		nnode.Dloadedstate = "pointsmeshactuallyloaded"
	else:
		nnode.pointmaterial = null

var potree_color_multfactor = 1/65535.0
var Dmaxcolorval = 0
var Dmaxcolorcheckpointcount = 0
func loadocellpointsmesh_InWorkerThread(onoderequest):
	var rootnode = onoderequest["rootnode"]
	var ocellcentre = onoderequest["ocellcentre"]
	var Dboxminmax = onoderequest["Dboxminmax"]
	var nnode = onoderequest["nnode"]
	var parentmesh = nnode.get_parent().mesh  if nnode.treedepth >= 1  else null
	print("loadocellpointsmesh treedepth ", nnode.treedepth, " ", nnode.name, "parentmesh ", parentmesh)

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_POINTS)
	st.set_material(nnode.pointmaterial)
	var Dnpointsnotinbox = 0
	var numPoints = nnode["numPoints"]
	var foctreeF = File.new()
	foctreeF.open(onoderequest["fetchednonimagedataobjectfile"], File.READ)
	print("aaa ", Dmaxcolorcheckpointcount, " ", Dmaxcolorval)
	if onoderequest["url"].substr(0, 4) != "http" or foctreeF.get_len() == onoderequest["byteSize"]:
		nnode.Dloadedstate = "pointsloading"
		for i in range(numPoints):
			var v0 = foctreeF.get_32()  
			var v1 = foctreeF.get_32()  
			var v2 = foctreeF.get_32()
			if rootnode.attributes_rgb_prebytes != -1:
				if rootnode.attributes_rgb_prebytes != 0:
					foctreeF.get_buffer(rootnode.attributes_rgb_prebytes)
				var r = foctreeF.get_16()  
				var g = foctreeF.get_16()  
				var b = foctreeF.get_16()
				if potree_color_multfactor != 0.0:
					var col = Color(r*potree_color_multfactor, g*potree_color_multfactor, b*potree_color_multfactor)
					Dmaxcolorval = max(max(Dmaxcolorval, r), max(g, b))
					st.add_color(col)
			if rootnode.attributes_postbytes != 0:
				foctreeF.get_buffer(rootnode.attributes_postbytes)
			var p = Vector3(v0*mdscale.x + mdoffset.x, 
							v1*mdscale.y + mdoffset.y, 
							v2*mdscale.z + mdoffset.z)
			st.add_vertex(p - ocellcentre)
			if not Dboxminmax.has_point(p):
				Dnpointsnotinbox += 1
		foctreeF.close()

		Dmaxcolorcheckpointcount += 1
		if Dmaxcolorcheckpointcount == 10 and rootnode.attributes_rgb_prebytes != -1:
			print("Max potree rgb color values ", Dmaxcolorval)
			if Dmaxcolorval < 256:
				if is_equal_approx(potree_color_multfactor, 1.0/65535):
					print("  *** should set potreecolorscale to 255")
			elif not is_equal_approx(potree_color_multfactor, 1.0/65535):
				print("  *** should set potreecolorscale to 65535")

		var relativeocellcentre = nnode.transform.origin
		if ocellcentre.distance_to((Dboxmin+Dboxmax)/2) > 0.9:
			print("moved centre ", ocellcentre, ((Dboxmin+Dboxmax)/2))
		var childIndex = int(nnode.get_name())
		nnode.Dloadedstate = "pointscarryingdown"
		numPointsCarriedDown = 0

		if parentmesh != null:
			var parentsurfacearrays = parentmesh.surface_get_arrays(0)
			var parentpoints = parentsurfacearrays[Mesh.ARRAY_VERTEX]
			var parentcolors = parentsurfacearrays[Mesh.ARRAY_COLOR] if (rootnode.attributes_rgb_prebytes != -1 and rootnode.potree_color_multfactor != 0.0) else null
			print("gotparentpoints ", len(parentpoints))
			for i in range(len(parentpoints)):
				var p = parentpoints[i]
				var pocellindex = (4 if p.x > 0.0 else 0) + \
								  (2 if p.y > 0.0 else 0) + \
								  (1 if p.z > 0.0 else 0) 
				if pocellindex == childIndex:
					var rp = p - relativeocellcentre
					if parentcolors != null:
						st.add_color(parentcolors[i])
					st.add_vertex(rp)
					numPointsCarriedDown += 1
					if not Dboxminmax.has_point(rp + ocellcentre):
						Dnpointsnotinbox += 1

		var pointmesh = Mesh.new()
		st.commit(pointmesh)
		nnode.Dloadedstate = "pointsmeshmade"
		print("saving pointmesh ", pointmesh)
		onoderequest["pointmesh"] = pointmesh

	else:
		nnode.Dloadedstate = "failedfetching"
		print("foctree nodesize bytes fail ", foctreeF.get_len(), " bytes not ", nnode.byteSize)
		onoderequest["pointmesh"] = null

