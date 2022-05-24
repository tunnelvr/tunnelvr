extends MeshInstance

var hierarchybyteOffset = 0
var hierarchybyteSize = 0

var childMask = 0
var spacing = 0
var powdiv2 = 1.0
var treedepth = 0
var numPoints = 0
var numPointsCarriedDown = 0
var byteOffset = 0
var byteSize = 0

var ocellmask = 0
var pointmaterial = null
var visibleincamera = false
var visibleincameratimestamp = 0
var ocellsize = Vector3(0,0,0)
var ocellorigin = Vector3(0,0,0)
var timestampatinvisibility = 0

var Dboxmin = Vector3(0,0,0)
var Dboxmax = Vector3(0,0,0)

const boxpointepsilon = 0.6
const spacingdivider = 1.55
const constructhcubes = false

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
		visibleincameratimestamp = OS.get_ticks_msec()*0.001
		
const Nloadcellpointsperframe = 3000
func Yloadoctcellpoints(foctreeF, pointsizefactor, roottransforminverse, rootnode):
	var mdscale = rootnode.mdscale
	var mdoffset = rootnode.mdoffset

	var ocellcentre = roottransforminverse*global_transform.origin
	var relativeocellcentre = transform.origin
	var childIndex = int(name)
	if ocellcentre.distance_to((Dboxmin+Dboxmax)/2) > 0.9:
		print("moved centre ", ocellcentre, ((Dboxmin+Dboxmax)/2))
	var Dboxminmax = AABB(ocellcentre - ocellsize/2, ocellsize).grow(boxpointepsilon)

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_POINTS)
	var Dnpointsnotinbox = 0
	
	yield(get_tree(), "idle_frame")
	var t0 = OS.get_ticks_msec()
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
			var col = Color(r/65535.0, g/65535.0, b/65535.0)
			st.add_color(col)
		if rootnode.attributes_postbytes != 0:
			foctreeF.get_buffer(rootnode.attributes_postbytes)

		var p = Vector3(v0*mdscale.x + mdoffset.x, 
						v1*mdscale.y + mdoffset.y, 
						v2*mdscale.z + mdoffset.z)
		st.add_vertex(p - ocellcentre)
		if not Dboxminmax.has_point(p):
			Dnpointsnotinbox += 1
		if ((i+1) % Nloadcellpointsperframe) == 0:
			var dt = OS.get_ticks_msec() - t0
			if dt > 20:
				print("Excessive Yloadoctcellpoints_A time ", dt)
			yield(get_tree(), "idle_frame")
			t0 = OS.get_ticks_msec()
		
	numPointsCarriedDown = 0
	if treedepth >= 1:
		var parentsurfacearrays = get_parent().mesh.surface_get_arrays(0)
		var parentpoints = parentsurfacearrays[Mesh.ARRAY_VERTEX]
		var parentcolors = parentsurfacearrays[Mesh.ARRAY_COLOR] if rootnode.attributes_rgb_prebytes != -1 else null
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
				if ((Nloadcellpointsperframe+numPointsCarriedDown) % Nloadcellpointsperframe) == 0:
					var dt = OS.get_ticks_msec() - t0
					if dt > 20:
						print("Excessive Yloadoctcellpoints_B time ", dt)
					yield(get_tree(), "idle_frame")
					t0 = OS.get_ticks_msec()
				numPointsCarriedDown += 1
				
				if not Dboxminmax.has_point(rp + ocellcentre):
					Dnpointsnotinbox += 1

	var dt = OS.get_ticks_msec() - t0
	if dt > 20:
		print("Excessive Yloadoctcellpoints_C time ", dt)
	t0 = OS.get_ticks_msec()		
	var pointmesh = Mesh.new()
	st.commit(pointmesh)
	mesh = pointmesh
	if Dnpointsnotinbox != 0:
		print("npointsnotinbox ", Dnpointsnotinbox, " of ", numPoints+numPointsCarriedDown)
	dt = OS.get_ticks_msec() - t0
	if dt > 20:
		print("Excessive Yloadoctcellpoints_D time ", dt)
	t0 = OS.get_ticks_msec()		
	pointmaterial = load("res://potreework/pointcloudslice.material").duplicate()
	pointmaterial.set_shader_param("point_scale", pointsizefactor*spacing)
	pointmaterial.set_shader_param("ocellcentre", ocellcentre)
	pointmaterial.set_shader_param("ocellmask", ocellmask)
	pointmaterial.set_shader_param("roottransforminverse", roottransforminverse)
	pointmaterial.set_shader_param("highlightplaneperp", rootnode.highlightplaneperp)
	pointmaterial.set_shader_param("highlightplanedot", rootnode.highlightplanedot)

	var colormixweight = 0.0
	if rootnode.attributes_rgb_prebytes != -1:
		colormixweight = 0.8 if Tglobal.housahedronmode else 0.5
	pointmaterial.set_shader_param("colormixweight", colormixweight)

	if Tglobal.housahedronmode:
		pointmaterial.set_shader_param("highlightdist", 0.15)
		pointmaterial.set_shader_param("highlightcol", Vector3(0.8,0.0,0.8))
		pointmaterial.set_shader_param("highlightcol2", Vector3(0.8,0.0,0.8))

	set_surface_material(0, pointmaterial)
	dt = OS.get_ticks_msec() - t0
	if dt > 20:
		print("Excessive Yloadoctcellpoints_E time ", dt)


func constructpotreenode(parentnode, childIndex, Droottransforminverse):
	spacing = parentnode.spacing/spacingdivider
	powdiv2 = parentnode.powdiv2/2.0
	
	treedepth = parentnode.treedepth + 1
	ocellsize = parentnode.ocellsize/2
	transform.origin = Vector3(ocellsize.x/2 if childIndex & 0b0100 else -ocellsize.x/2, 
							   ocellsize.y/2 if childIndex & 0b0010 else -ocellsize.y/2, 
							   ocellsize.z/2 if childIndex & 0b0001 else -ocellsize.z/2)
	ocellorigin = parentnode.ocellorigin + transform.origin
	
	createChildAABB(parentnode, childIndex)
	name = "c%d" % childIndex
	var kcen = Droottransforminverse*parentnode.global_transform.origin + transform.origin
	if kcen.distance_to((Dboxmin+Dboxmax)/2) > 0.9:
		print("kkmoved centre ", kcen, ((Dboxmin+Dboxmax)/2))
	assert (not parentnode.has_node(name))
	constructcontainingmesh()

func constructcontainingmesh():
	var visnote = VisibilityNotifier.new()
	visnote.name = "visnote"
	visnote.aabb = AABB(-ocellsize/2, ocellsize)
	visnote.visible = false
	add_child(visnote)
	visnote.connect("camera_entered", self, "on_camera_entered")
	visnote.connect("camera_exited", self, "on_camera_exited")
	if constructhcubes:
		mesh = CubeMesh.new()
		mesh.surface_set_material(0, load("res://potreework/ocellcube.material"))
		mesh.size = ocellsize if ocellsize.x < 5 else Vector3(5,5,5)
		visible = true




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
		assert ((ntype == 0) or (childMask == 0))


const Nhierarchyframe = 30
func Yloadhierarchychunk(fhierarchyF, Droottransforminverse):
	assert (name[0] == "h")
	name[0] = "c"
	
	yield(get_tree(), "idle_frame")
	var nodes = [ self ]
	for i in range(hierarchybyteSize/22):
		var pnode = nodes[i]
		pnode.loadnodedefinition(fhierarchyF)
		if pnode.name[0] != "h":
			for childIndex in range(8):
				if (pnode.childMask & (1 << childIndex)):
					var cnode = MeshInstance.new()
					cnode.set_script(load("res://potreework/Onode.gd"))
					cnode.constructpotreenode(pnode, childIndex, Droottransforminverse)
					cnode.visible = false
					cnode.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
					pnode.add_child(cnode)
					nodes.append(cnode)
					if (len(nodes) % Nhierarchyframe) == 0:
						yield(get_tree(), "idle_frame")
	return nodes


