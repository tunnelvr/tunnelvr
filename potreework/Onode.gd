extends MeshInstance

var childMask = 0
var spacing = 0
var treedepth = 0
var isdefinitionloaded = false
var isleaf = false
var numPoints = 0
var byteOffset = 0
var byteSize = 0
var pointmaterial = null
const makecubecontainer = true

var boxmin = Vector3(0,0,0)
var boxmax = Vector3(0,0,0)

func createChildAABB(pnode, index):
	boxmin = pnode.boxmin
	boxmax = pnode.boxmax
	var boxsize = boxmax - boxmin
	if ((index & 0b0001) > 0):
		boxmin.z += boxsize.z / 2;
	else:
		boxmax.z -= boxsize.z / 2;

	if ((index & 0b0010) > 0):
		boxmin.y += boxsize.y / 2;
	else:
		boxmax.y -= boxsize.y / 2;
	
	if ((index & 0b0100) > 0):
		boxmin.x += boxsize.x / 2;
	else:
		boxmax.x -= boxsize.x / 2;

func setocellmask():
	var ocellmask = 0
	for cnode in get_children():
		if len(cnode.name) == 1:
			if cnode.pointmaterial != null and cnode.visible:
				ocellmask |= (1 << int(cnode.name))
	pointmaterial.set_shader_param("ocellmask", ocellmask)


func loadoctcellpoints(foctree, mdscale, mdoffset, pointsizefactor):
	if makecubecontainer:
		var cc = MeshInstance.new()
		cc.mesh = mesh
		cc.name = "cubemesh"
		cc.mesh.surface_set_material(0, load("res://potreework/ocellcube2.material"))
		add_child(cc)

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_POINTS)
	foctree.seek(byteOffset)
	var xmin = 0
	var xmax = 0
	var ymin = 0
	var ymax = 0
	var zmin = 0
	var zmax = 0
	for i in range(numPoints):
		var v0 = foctree.get_32()
		var v1 = foctree.get_32()
		var v2 = foctree.get_32()
		var p = Vector3(v0*mdscale.x + mdoffset.x, 
						v1*mdscale.y + mdoffset.y, 
						v2*mdscale.z + mdoffset.z)
		st.add_vertex(p - global_transform.origin)
		if i == 0 or p.x < xmin:  xmin = p.x
		if i == 0 or p.x > xmax:  xmax = p.x
		if i == 0 or p.y < ymin:  ymin = p.y
		if i == 0 or p.y > ymax:  ymax = p.y
		if i == 0 or p.z < zmin:  zmin = p.z
		if i == 0 or p.z > zmax:  zmax = p.z
		
	if len(name) == 1:
		var arr = get_parent().mesh.surface_get_arrays(0)[Mesh.PRIMITIVE_POINTS]
		for i in len(arr):
			pass # finish deciding which side of the centre it is and add them in
			
		
	var pointsmesh = Mesh.new()
	st.commit(pointsmesh)
	mesh = pointsmesh
	print(numPoints, " mesh ", name, boxmin, "< ", Vector3(xmin, ymin, zmin), "<", Vector3(xmax, ymax, zmax), " <", boxmax)
	pointmaterial = load("res://potreework/pointcloudslice.material").duplicate()
	pointmaterial.set_shader_param("point_scale", pointsizefactor*spacing)
	pointmaterial.set_shader_param("ocellcentre", global_transform.origin)
	print("centre ", global_transform.origin, ((boxmin+boxmax)/2))
	set_surface_material(0, pointmaterial)

func constructnode(parentnode, childIndex):
	createChildAABB(parentnode, childIndex)
	name = str(childIndex)
	mesh = CubeMesh.new()
	mesh.surface_set_material(0, load("res://potreework/ocellcube.material"))
	mesh.size = parentnode.mesh.size/2
	transform.origin = Vector3(mesh.size.z/2 if childIndex & 0b0001 else -mesh.size.z/2, 
							   mesh.size.y/2 if childIndex & 0b0010 else -mesh.size.y/2, 
							   mesh.size.x/2 if childIndex & 0b0100 else -mesh.size.x/2)
	spacing = parentnode.spacing/2
	treedepth = parentnode.treedepth + 1
	assert (not parentnode.has_node(name))
	#visible = (treedepth < 4)

func loadnodedefinition(fhierarchy):
	var ntype = fhierarchy.get_8()
	childMask = fhierarchy.get_8()
	numPoints = fhierarchy.get_32()
	byteOffset = fhierarchy.get_64()
	byteSize = fhierarchy.get_64()
	isdefinitionloaded = (ntype != 2)
	isleaf = (ntype == 1)
	assert (isdefinitionloaded or (byteOffset+byteSize <= fhierarchy.get_len()))
	assert (not isdefinitionloaded or (isleaf == (childMask == 0)))

func loadrootdefinition(metadata, mdoffset):
	byteSize = metadata["hierarchy"]["firstChunkSize"]
	var mdmin = Vector3(metadata["boundingBox"]["min"][0], 
						metadata["boundingBox"]["min"][1], 
						metadata["boundingBox"]["min"][2])
	var mdmax = Vector3(metadata["boundingBox"]["max"][0], 
						metadata["boundingBox"]["max"][1], 
						metadata["boundingBox"]["max"][2])
	boxmin = mdmin
	boxmax = mdmax
	print("yyy ", boxmin, boxmax)
	mesh = CubeMesh.new()
	mesh.surface_set_material(0, load("res://potreework/ocellcube.material"))
	mesh.size = mdmax-mdmin
	transform.origin = (mdmax+mdmin)/2
	spacing = metadata["spacing"]

func loadhierarchychunk(fhierarchy):
	assert (!isdefinitionloaded)
	fhierarchy.seek(byteOffset)
	var nodes = [ self ]
	for i in range(byteSize/22):
		var pnode = nodes[i]
		pnode.loadnodedefinition(fhierarchy)
		if pnode.isdefinitionloaded:
			assert (pnode.get_child_count() == 0)
			for childIndex in range(8):
				if (pnode.childMask & (1 << childIndex)):
					var cnode = MeshInstance.new()
					cnode.set_script(pnode.get_script())
					cnode.constructnode(pnode, childIndex)
					pnode.add_child(cnode)
					nodes.append(cnode)
	return nodes


