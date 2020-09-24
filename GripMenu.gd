extends Spatial

var gripmenupointertargetpoint = Vector3(0,0,0)
var gripmenulaservector = Vector3(0,0,1)
var gripmenupointertargetwall = null
var gripmenupointertargettype = ""

var previewtubematerials = { }
var tubenamematerials = { }

func _ready():
	var tubematerials = get_node("/root/Spatial/MaterialSystem/tubematerials")
	var MaterialButton = load("res://nodescenes/MaterialButton.tscn")
	for i in range(tubematerials.get_child_count()):
		var tubematerial = tubematerials.get_child(i)
		var materialbutton = MaterialButton.instance()
		var materialname = tubematerial.get_name()
		materialbutton.set_name(materialname)
		var material = tubematerial.get_surface_material(0).duplicate()
		material.flags_unshaded = true
		material.uv1_triplanar = false
		previewtubematerials[materialname] = material
		tubenamematerials[materialname] = tubematerial.get_node("name").get_surface_material(0)
		materialbutton.get_node("MeshInstance").set_surface_material(0, material)
		$MaterialButtons.add_child(materialbutton)
		materialbutton.transform.origin = Vector3(0.25, 0.15 - i*0.11, 0)
	disableallgripmenus()
	
func disableallgripmenus():
	for s in $WordButtons.get_children():
		s.get_node("MeshInstance").visible = false
		s.get_node("CollisionShape").disabled = true
	gripmenupointertargetwall = null
	gripmenupointertargettype = ""
	for s in $MaterialButtons.get_children():
		s.get_node("MeshInstance").visible = false
		s.get_node("CollisionShape").disabled = true

func enablegripmenus(gmlist):
	for g in gmlist:
		if g == "materials":
			for s in $MaterialButtons.get_children():
				s.get_node("MeshInstance").visible = true
				s.get_node("CollisionShape").disabled = false
		elif g != "":
			$WordButtons.get_node(g).get_node("MeshInstance").visible = true
			$WordButtons.get_node(g).get_node("CollisionShape").disabled = false



func cleargripmenupointer(pointertarget):
	if pointertarget.get_parent().get_name() == "MaterialButtons":
		pointertarget.get_node("MeshInstance").set_surface_material(0, previewtubematerials[pointertarget.get_name()])
	else:
		pointertarget.get_node("MeshInstance").get_surface_material(0).albedo_color = Color("#E8D619")

func setgripmenupointer(pointertarget):
	if pointertarget.get_parent().get_name() == "MaterialButtons":
		pointertarget.get_node("MeshInstance").set_surface_material(0, tubenamematerials[pointertarget.get_name()])
	else:
		pointertarget.get_node("MeshInstance").get_surface_material(0).albedo_color = Color("#FFCCCC")


func gripmenuon(controllertrans, pointertargetpoint, pointertargetwall, pointertargettype, activetargettube):
	gripmenupointertargetpoint = pointertargetpoint if pointertargetpoint != null else controllertrans.origin
	gripmenupointertargetwall = pointertargetwall
	gripmenulaservector = -controllertrans.basis.z
	gripmenupointertargettype = pointertargettype

	var paneltrans = global_transform
	paneltrans.origin = controllertrans.origin - 0.8*ARVRServer.world_scale*(controllertrans.basis.z)
	var lookatpos = controllertrans.origin - 1.6*ARVRServer.world_scale*(controllertrans.basis.z)
	paneltrans = paneltrans.looking_at(lookatpos, Vector3(0, 1, 0))
	global_transform = paneltrans

	if gripmenupointertargettype == "XCdrawing" and gripmenupointertargetwall.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE:
		enablegripmenus(["Up5", "Down5", "toPaper"])

	elif gripmenupointertargettype == "XCdrawing" and gripmenupointertargetwall.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
		if is_instance_valid(activetargettube) and ((gripmenupointertargetwall.get_name() == activetargettube.xcname0) or (gripmenupointertargetwall.get_name() == activetargettube.xcname1)):
			enablegripmenus(["NewSlice", "DelXC"])
		elif is_instance_valid(activetargettube) and len(gripmenupointertargetwall.nodepoints) == 0:
			enablegripmenus(["DoSlice", "DelXC"])
		else:
			enablegripmenus(["DelXC"])

	elif gripmenupointertargettype == "Papersheet":
		enablegripmenus(["toFloor", "toBig"])
		
	elif gripmenupointertargettype == "XCtubesector":
		enablegripmenus(["SelectXC", "ghost", "materials"])

	elif gripmenupointertargettype == "XCnode":
		enablegripmenus(["NewXC", "Record", "Replay"])

	else:
		enablegripmenus(["NewXC", "", ""])
				

# Calibri Fontsize 20: height 664 width 159
var grip_commands_text = """
Z+5
Z-5
to Paper
to Solid
to Gas
to Floor
to Big
new Slice
do Slice
deleteXC
SelectXC
floorTex
ghost
f14
f15
f16
f17
f18
f19
f20"""

