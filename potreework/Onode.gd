extends MeshInstance

var childMask = 0
var spacing = 0
var isnotloaded = true
var isleaf = false
var numPoints = 0
var byteOffset = 0
var byteSize = 0
var pointmaterial = null

func loadoctcellpoints(foctree, mdscale, mdoffset):
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
	set_surface_material(0, pointmaterial)

	
func loadtreechunk(fhierarchy, duplicatepointmaterial):
	assert (isnotloaded)
	fhierarchy.seek(byteOffset)
	var nodes = [ self ]
	for i in range(byteSize/22):
		var pnode = nodes[i]
		
		var ntype = fhierarchy.get_8()
		pnode.isnotloaded = (ntype == 2)
		pnode.isleaf = (ntype == 1)
		pnode.childMask = fhierarchy.get_8()
		pnode.numPoints = fhierarchy.get_32()
		pnode.byteOffset = fhierarchy.get_64()
		pnode.byteSize = fhierarchy.get_64()
		assert (pnode.isnotloaded or (pnode.isleaf == (pnode.childMask == 0)))
		
		if not pnode.isnotloaded:
			assert (pnode.get_child_count() == 0)
			for childIndex in range(8):
				if ((1 << childIndex) & pnode.childMask):
					var cnode = MeshInstance.new()
					cnode.name = str(childIndex)
					cnode.set_script(pnode.get_script())
					cnode.mesh = pnode.mesh.duplicate()
					cnode.mesh.size = pnode.mesh.size/2
					cnode.transform.origin = Vector3(cnode.mesh.size.x/2 if childIndex & 0b0001 else -cnode.mesh.size.x/2, 
													 cnode.mesh.size.y/2 if childIndex & 0b0010 else -cnode.mesh.size.y/2, 
													 cnode.mesh.size.z/2 if childIndex & 0b0100 else -cnode.mesh.size.z/2)
					cnode.spacing = pnode.spacing/2
					if duplicatepointmaterial:
						cnode.pointmaterial = pnode.pointmaterial.duplicate()
						cnode.pointmaterial.set_shader_param("point_scale", pnode.pointmaterial.get_shader_param("point_scale")/2)
					else:
						cnode.pointmaterial = pnode.pointmaterial
					assert (not pnode.has_node(cnode.name))
					pnode.add_child(cnode)
					nodes.append(cnode)
	return nodes


