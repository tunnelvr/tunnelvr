extends Spatial



var gripmenupointertargetpoint = Vector3(0,0,0)
var gripmenulaservector = Vector3(0,0,1)
var gripmenupointertargetwall = null
var gripmenupointertargettype = ""


func disableallgripmenus():
	for s in get_children():
		s.get_node("MeshInstance").visible = false
		s.get_node("CollisionShape").disabled = true
	gripmenupointertargetwall = null
	gripmenupointertargettype = ""

func enablegripmenus(gmlist):
	for g in gmlist:
		if g != "":
			get_node(g).get_node("MeshInstance").visible = true
			get_node(g).get_node("CollisionShape").disabled = false
	
func _ready():
	disableallgripmenus()

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
		
	elif gripmenupointertargettype == "XCtube":
		enablegripmenus(["SelectXC", "ghost", "FloorTex"])
	elif gripmenupointertargettype == "XCtubesector":
		enablegripmenus(["SelectXC", "ghost", "FloorTex"])

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

