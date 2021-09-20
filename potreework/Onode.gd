extends MeshInstance

var childMask = 0
var spacing = 0
var isdefinitionloaded = false
var isleaf = false
var numPoints = 0
var byteOffset = 0
var byteSize = 0
var pointmaterial = null


func loadoctcellpoints(foctree, mdscale, mdoffset, pointsizefactor):
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_POINTS)
	foctree.seek(byteOffset)
	for i in range(numPoints):
		var v0 = foctree.get_32()
		var v1 = foctree.get_32()
		var v2 = foctree.get_32()
		var p = Vector3(v0*mdscale.x + mdoffset.x, v2*mdscale.y + mdoffset.y, -v1*mdscale.z + mdoffset.z)
		st.add_vertex(p-global_transform.origin)
	var pointsmesh = Mesh.new()
	st.commit(pointsmesh)
	mesh = pointsmesh
	pointmaterial = load("res://potreework/pointcloudslice.material").duplicate()
	pointmaterial.set_shader_param("point_scale", pointsizefactor*spacing)	
	set_surface_material(0, pointmaterial)

func constructnode(parentnode, childIndex):
	name = str(childIndex)
	mesh = CubeMesh.new()
	mesh.surface_set_material(0, load("res://potreework/ocellcube.material"))
	mesh.size = parentnode.mesh.size/2
	transform.origin = Vector3(mesh.size.x/2 if childIndex & 0b0001 else -mesh.size.x/2, 
							   mesh.size.y/2 if childIndex & 0b0010 else -mesh.size.y/2, 
							   mesh.size.z/2 if childIndex & 0b0100 else -mesh.size.z/2)
	spacing = parentnode.spacing/2
	assert (not parentnode.has_node(name))

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
	numPoints = int(byteSize/22)
	var mdmin = Vector3(metadata["boundingBox"]["min"][0], metadata["boundingBox"]["min"][2], -metadata["boundingBox"]["min"][1])
	var mdmax = Vector3(metadata["boundingBox"]["max"][0], metadata["boundingBox"]["max"][2], -metadata["boundingBox"]["max"][1])
	mesh = CubeMesh.new()
	mesh.surface_set_material(0, load("res://potreework/ocellcube.material"))
	mesh.size = mdmax-mdmin
	transform.origin = (mdmax-mdmin)/2-mdoffset
	spacing = metadata["spacing"]


func loadhierarchychunk(fhierarchy):
	assert (!isdefinitionloaded)
	fhierarchy.seek(byteOffset)
	var nodes = [ self ]
	assert (byteSize == 22*numPoints)
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


