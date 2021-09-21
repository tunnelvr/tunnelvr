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
var visibleincamera = false

var boxmin = Vector3(0,0,0)
var boxmax = Vector3(0,0,0)
const boxpointepsilon = 0.6

func createChildAABB(pnode, index):
	boxmin = pnode.boxmin
	boxmax = pnode.boxmax
	var boxsize = boxmax - boxmin
	if ((index & 0b0100) > 0): boxmin.x += boxsize.x / 2;
	else:                      boxmax.x -= boxsize.x / 2;

	if ((index & 0b0010) > 0): boxmin.y += boxsize.y / 2;
	else:                      boxmax.y -= boxsize.y / 2;

	if ((index & 0b0001) > 0): boxmin.z += boxsize.z / 2;
	else:                      boxmax.z -= boxsize.z / 2;
	

func on_camera_entered(camera):
	if camera.get_instance_id() == Tglobal.primarycamera_instanceid:
		visibleincamera = true
func on_camera_exited(camera):
	if camera.get_instance_id() == Tglobal.primarycamera_instanceid:
		visibleincamera = false

func setocellmask():
	var ocellmask = 0
	for cnode in get_children():
		if cnode.name[0] == "n" or cnode.name[0] == "l":
			if cnode.pointmaterial != null and cnode.visible:
				ocellmask |= (1 << int(cnode.name))
	pointmaterial.set_shader_param("ocellmask", ocellmask)

func loadoctcellpoints(foctree, mdscale, mdoffset, pointsizefactor):
	var ocellcentre = global_transform.origin
	var relativeocellcentre = transform.origin
	var childIndex = int(name)
	var boxminmax = AABB(boxmin, boxmax-boxmin).grow(boxpointepsilon)
	if ocellcentre.distance_to((boxmin+boxmax)/2) > 0.9:
		print("moved centre ", ocellcentre, ((boxmin+boxmax)/2))

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_POINTS)
	foctree.seek(byteOffset)
	var npointsnotinbox = 0
	for i in range(numPoints):
		var v0 = foctree.get_32()
		var v1 = foctree.get_32()
		var v2 = foctree.get_32()
		var p = Vector3(v0*mdscale.x + mdoffset.x, 
						v1*mdscale.y + mdoffset.y, 
						v2*mdscale.z + mdoffset.z)
		st.add_vertex(p - ocellcentre)
		if not boxminmax.has_point(p):
			npointsnotinbox += 1
		
	if len(name) <= 2:
		var parentpoints = get_parent().mesh.surface_get_arrays(0)[Mesh.PRIMITIVE_POINTS]
		for p in parentpoints:
			var pocellindex = (4 if p.x > 0.0 else 0) + \
							  (2 if p.y > 0.0 else 0) + \
							  (1 if p.z > 0.0 else 0) 
			if pocellindex == childIndex:
				var rp = p - relativeocellcentre
				st.add_vertex(rp)
				if not boxminmax.has_point(rp + ocellcentre):
					npointsnotinbox += 1

	var pointsmesh = Mesh.new()
	st.commit(pointsmesh)
	mesh = pointsmesh
	if npointsnotinbox != 0:
		print("npointsnotinbox ", npointsnotinbox, " of ", numPoints)
	pointmaterial = load("res://potreework/pointcloudslice.material").duplicate()
	pointmaterial.set_shader_param("point_scale", pointsizefactor*spacing)
	pointmaterial.set_shader_param("ocellcentre", ocellcentre)
	set_surface_material(0, pointmaterial)

func constructnode(parentnode, childIndex):
	spacing = parentnode.spacing/1.7
	treedepth = parentnode.treedepth + 1
	var meshsize = parentnode.mesh.size/2
	transform.origin = Vector3(meshsize.x/2 if childIndex & 0b0100 else -meshsize.x/2, 
							   meshsize.y/2 if childIndex & 0b0010 else -meshsize.y/2, 
							   meshsize.z/2 if childIndex & 0b0001 else -meshsize.z/2)

	createChildAABB(parentnode, childIndex)
	name = "c%d" % childIndex
	var kcen = parentnode.global_transform.origin + transform.origin
	if kcen.distance_to((boxmin+boxmax)/2) > 0.9:
		print("kkmoved centre ", kcen, ((boxmin+boxmax)/2))
	assert (not parentnode.has_node(name))
	constructcontainingmesh(meshsize)


func constructcontainingmesh(meshsize):
	mesh = CubeMesh.new()
	mesh.surface_set_material(0, load("res://potreework/ocellcube.material"))
	mesh.size = meshsize
	var visnote = VisibilityNotifier.new()
	visnote.name = "visnote"
	visnote.aabb = AABB(-meshsize/2, meshsize)
	visnote.visible = false
	add_child(visnote)
	visnote.connect("camera_entered", self, "on_camera_entered")
	visnote.connect("camera_exited", self, "on_camera_exited")

func loadnodedefinition(fhierarchy):
	var ntype = fhierarchy.get_8()
	childMask = fhierarchy.get_8()
	numPoints = fhierarchy.get_32()
	byteOffset = fhierarchy.get_64()
	byteSize = fhierarchy.get_64()
	isdefinitionloaded = (ntype != 2)
	isleaf = (ntype == 1)
	assert (name[0] == "c")
	name[0] = ["n", "l", "h"][ntype]
	assert (isdefinitionloaded or (byteOffset+byteSize <= fhierarchy.get_len()))
	assert (not isdefinitionloaded or (isleaf == (childMask == 0)))

func loadhierarchychunk(fhierarchy):
	assert (!isdefinitionloaded)
	assert (name[0] == "h")
	name[0] = "c"
	fhierarchy.seek(byteOffset)
	var nodes = [ self ]
	for i in range(byteSize/22):
		var pnode = nodes[i]
		pnode.loadnodedefinition(fhierarchy)
		if pnode.isdefinitionloaded:
			#assert (pnode.get_child_count() == 0)
			for childIndex in range(8):
				if (pnode.childMask & (1 << childIndex)):
					var cnode = MeshInstance.new()
					cnode.set_script(load("res://potreework/Onode.gd"))
					cnode.constructnode(pnode, childIndex)
					pnode.add_child(cnode)
					nodes.append(cnode)
	return nodes


