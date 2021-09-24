extends MeshInstance

var hierarchybyteOffset = 0
var hierarchybyteSize = 0

var childMask = 0
var spacing = 0
var treedepth = 0
var numPoints = 0
var numPointsCarriedDown = 0
var byteOffset = 0
var byteSize = 0

var ocellmask = 0
var pointmaterial = null
var visibleincamera = false
var ocellsize = Vector3(0,0,0)
var timestampatinvisibility = 0

var Dboxmin = Vector3(0,0,0)
var Dboxmax = Vector3(0,0,0)

const boxpointepsilon = 0.6
const spacingdivider = 1.7
const constructhcubes = true

func createChildAABB(pnode, index):
	Dboxmin = pnode.Dboxmin
	Dboxmax = pnode.Dboxmax
	var boxsize = Dboxmax - Dboxmin
	if ((index & 0b0100) > 0): Dboxmin.x += boxsize.x / 2;
	else:                      Dboxmax.x -= boxsize.x / 2;

	if ((index & 0b0010) > 0): Dboxmin.y += boxsize.y / 2;
	else:                      Dboxmax.y -= boxsize.y / 2;

	if ((index & 0b0001) > 0): Dboxmin.z += boxsize.z / 2;
	else:                      Dboxmax.z -= boxsize.z / 2;
	

func on_camera_entered(camera):
	if camera.get_instance_id() == Tglobal.primarycamera_instanceid:
		visibleincamera = true
func on_camera_exited(camera):
	if camera.get_instance_id() == Tglobal.primarycamera_instanceid:
		visibleincamera = false

func loadoctcellpoints(foctreeF, mdscale, mdoffset, pointsizefactor, roottransforminverse):
	var ocellcentre = roottransforminverse*global_transform.origin
	var relativeocellcentre = transform.origin
	var childIndex = int(name)
	if ocellcentre.distance_to((Dboxmin+Dboxmax)/2) > 0.9:
		print("moved centre ", ocellcentre, ((Dboxmin+Dboxmax)/2))
	#var boxminmax = AABB(boxmin, boxmax-boxmin).grow(boxpointepsilon)
	var Dboxminmax = AABB(ocellcentre - ocellsize/2, ocellsize).grow(boxpointepsilon)

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_POINTS)
	var Dnpointsnotinbox = 0
	for i in range(numPoints):
		var v0 = foctreeF.get_32()
		var v1 = foctreeF.get_32()
		var v2 = foctreeF.get_32()
		var p = Vector3(v0*mdscale.x + mdoffset.x, 
						v1*mdscale.y + mdoffset.y, 
						v2*mdscale.z + mdoffset.z)
		st.add_vertex(p - ocellcentre)
		if not Dboxminmax.has_point(p):
			Dnpointsnotinbox += 1
		
	numPointsCarriedDown = 0
	if treedepth >= 1:
		var parentpoints = get_parent().mesh.surface_get_arrays(0)[Mesh.PRIMITIVE_POINTS]
		for p in parentpoints:
			var pocellindex = (4 if p.x > 0.0 else 0) + \
							  (2 if p.y > 0.0 else 0) + \
							  (1 if p.z > 0.0 else 0) 
			if pocellindex == childIndex:
				var rp = p - relativeocellcentre
				st.add_vertex(rp)
				numPointsCarriedDown += 1
				if not Dboxminmax.has_point(rp + ocellcentre):
					Dnpointsnotinbox += 1

	var pointsmesh = Mesh.new()
	st.commit(pointsmesh)
	mesh = pointsmesh
	if Dnpointsnotinbox != 0:
		print("npointsnotinbox ", Dnpointsnotinbox, " of ", numPoints+numPointsCarriedDown)
	pointmaterial = load("res://potreework/pointcloudslice.material").duplicate()
	pointmaterial.set_shader_param("point_scale", pointsizefactor*spacing)
	pointmaterial.set_shader_param("ocellcentre", ocellcentre)
	pointmaterial.set_shader_param("ocellmask", ocellmask)
	pointmaterial.set_shader_param("roottransforminverse", roottransforminverse)
	set_surface_material(0, pointmaterial)



func constructnode(parentnode, childIndex, Droottransforminverse):
	spacing = parentnode.spacing/spacingdivider
	treedepth = parentnode.treedepth + 1
	ocellsize = parentnode.ocellsize/2
	transform.origin = Vector3(ocellsize.x/2 if childIndex & 0b0100 else -ocellsize.x/2, 
							   ocellsize.y/2 if childIndex & 0b0010 else -ocellsize.y/2, 
							   ocellsize.z/2 if childIndex & 0b0001 else -ocellsize.z/2)

	createChildAABB(parentnode, childIndex)
	name = "c%d" % childIndex
	var kcen = Droottransforminverse*parentnode.global_transform.origin + transform.origin
	if kcen.distance_to((Dboxmin+Dboxmax)/2) > 0.9:
		print("kkmoved centre ", kcen, ((Dboxmin+Dboxmax)/2))
	assert (not parentnode.has_node(name))
	constructcontainingmesh()

func constructcontainingmesh():
	if constructhcubes:
		mesh = CubeMesh.new()
		mesh.surface_set_material(0, load("res://potreework/ocellcube.material"))
		mesh.size = ocellsize
	var visnote = VisibilityNotifier.new()
	visnote.name = "visnote"
	visnote.aabb = AABB(-ocellsize/2, ocellsize)
	visnote.visible = false
	add_child(visnote)
	visnote.connect("camera_entered", self, "on_camera_entered")
	visnote.connect("camera_exited", self, "on_camera_exited")

func loadnodedefinition(fhierarchy):
	assert (name[0] == "c")
	var ntype = fhierarchy.get_8()
	childMask = fhierarchy.get_8()
	numPoints = fhierarchy.get_32()
	if ntype == 2:
		hierarchybyteOffset = fhierarchy.get_64()
		hierarchybyteSize = fhierarchy.get_64()
		name[0] = "h"
	else:
		byteOffset = fhierarchy.get_64()
		byteSize = fhierarchy.get_64()
		name[0] = ("n" if ntype == 0 else  "l")
		assert ((ntype == 1) == (childMask == 0))


func loadhierarchychunk(fhierarchyF, Droottransforminverse):
	assert (name[0] == "h")
	name[0] = "c"
	
	var nodes = [ self ]
	for i in range(hierarchybyteSize/22):
		var pnode = nodes[i]
		pnode.loadnodedefinition(fhierarchyF)
		if pnode.name[0] != "h":
			for childIndex in range(8):
				if (pnode.childMask & (1 << childIndex)):
					var cnode = MeshInstance.new()
					cnode.set_script(load("res://potreework/Onode.gd"))
					cnode.constructnode(pnode, childIndex, Droottransforminverse)
					cnode.visible = false
					cnode.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
					pnode.add_child(cnode)
					nodes.append(cnode)
	return nodes


