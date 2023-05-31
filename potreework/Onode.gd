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
var Dloadedstate = "notloaded"

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
#		assert ((ntype == 0) or (childMask == 0))
	if numPoints == 0:
		print("zero numPoints case ", get_path())

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


