extends Spatial

const handmodelfile1 = "res://addons/godot_ovrmobile/example_scenes/left_hand_model.glb"
const handmodelfile2 = "res://addons/godot_ovrmobile/example_scenes/right_hand_model.glb"

const hand_bone_mappings = [0, 23,  1, 2, 3, 4,  6, 7, 8,  10, 11, 12,  14, 15, 16, 18, 19, 20, 21];
var ovr_hand_tracking = null
var playerishandtracked = false
var islefthand = false
var handcontroller = null
var controller_id = 0
var handmodel = null
var handarmature = null
var handskeleton = null
var meshnode = null
var handmaterial = null
var joypos = Vector2(0, 0)

var controllerhandtransform = null
var mousecontrollermotioncumulative = Vector2(0, 0)
var gripbuttonheld = false
var triggerbuttonheld = false
var indexfingerpinchbutton = null
var middlefingerpinchbutton = null

var handscale = 0.0
var handconfidence = 0
var handvalid = false
var hand_boneorientations = [ Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ), Quat( 0.467562, 0.371268, 0.0784822, 0.798365 ), Quat( 0.253112, 0.141304, 0.155991, 0.944264 ), Quat( -0.0820883, -0.0530134, 0.190872, 0.976739 ), Quat( 0.0813293, 0.0570069, 0.0396865, 0.994264 ), Quat( 0.0443113, 0.0529943, 0.211373, 0.974961 ), Quat( -0.0262251, 0.000635884, 0.291161, 0.956315 ), Quat( -0.0167604, -0.0247861, 0.0716335, 0.996982 ), Quat( -0.0144094, -0.0484558, 0.17288, 0.983645 ), Quat( -0.0127633, -0.000258344, 0.341284, 0.939874 ), Quat( -0.0484786, 0.00163537, 0.0500899, 0.997566 ), Quat( -0.0682813, -0.113321, 0.185936, 0.973614 ), Quat( -0.0401938, 0.00888745, 0.348554, 0.936384 ), Quat( -0.0114638, 0.0296684, 0.146252, 0.988736 ), Quat( -0.207036, -0.140343, 0.0183118, 0.968042 ), Quat( 0.0544313, -0.108607, 0.254061, 0.959528 ), Quat( -0.0522058, -0.0357106, 0.158563, 0.985321 ), Quat( 0.00130541, 0.0483228, 0.170572, 0.984159 ), Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ) ]

const gestureboneorientations = { 
	"handokay00":[ Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ), Quat( 0.467562, 0.371268, 0.0784822, 0.798365 ), Quat( 0.253112, 0.141304, 0.155991, 0.944264 ), Quat( -0.0820883, -0.0530134, 0.190872, 0.976739 ), Quat( 0.0813293, 0.0570069, 0.0396865, 0.994264 ), Quat( 0.0443113, 0.0529943, 0.211373, 0.974961 ), Quat( -0.0262251, 0.000635884, 0.291161, 0.956315 ), Quat( -0.0167604, -0.0247861, 0.0716335, 0.996982 ), Quat( -0.0144094, -0.0484558, 0.17288, 0.983645 ), Quat( -0.0127633, -0.000258344, 0.341284, 0.939874 ), Quat( -0.0484786, 0.00163537, 0.0500899, 0.997566 ), Quat( -0.0682813, -0.113321, 0.185936, 0.973614 ), Quat( -0.0401938, 0.00888745, 0.348554, 0.936384 ), Quat( -0.0114638, 0.0296684, 0.146252, 0.988736 ), Quat( -0.207036, -0.140343, 0.0183118, 0.968042 ), Quat( 0.0544313, -0.108607, 0.254061, 0.959528 ), Quat( -0.0522058, -0.0357106, 0.158563, 0.985321 ), Quat( 0.00130541, 0.0483228, 0.170572, 0.984159 ), Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ) ],
	"handokay10":[ Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ), Quat( 0.492735, 0.354362, 0.103353, 0.788009 ), Quat( 0.256355, 0.0956267, 0.144365, 0.950945 ), Quat( -0.0816594, -0.0502562, 0.218979, 0.971007 ), Quat( 0.084894, 0.0725345, -0.157577, 0.981173 ), Quat( 0.0949116, 0.100794, 0.477651, 0.867572 ), Quat( -0.0261218, 0.00155448, 0.323766, 0.945775 ), Quat( -0.0169196, -0.0238768, 0.119608, 0.99239 ), Quat( -0.00877956, -0.00536436, 0.174319, 0.984636 ), Quat( -0.011972, -0.00288329, 0.127877, 0.991714 ), Quat( -0.0344616, -0.00455115, -0.0916157, 0.995188 ), Quat( -0.0491183, -0.0784361, -0.0137709, 0.995613 ), Quat( -0.0364712, 0.00137097, 0.129095, 0.99096 ), Quat( -0.00430107, 0.0292692, -0.00750024, 0.999534 ), Quat( -0.207036, -0.140343, 0.0183118, 0.968042 ), Quat( 0.105822, -0.0387376, -0.140094, 0.983705 ), Quat( -0.0454153, -0.0393059, 0.0768608, 0.995231 ), Quat( 0.000672678, 0.0491727, -0.0159533, 0.998663 ), Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ) ],
	"handokay01":[ Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ), Quat( 0.511247, 0.341179, 0.122062, 0.77931 ), Quat( 0.253986, 0.129789, 0.153086, 0.946156 ), Quat( -0.0804297, -0.0438226, 0.282298, 0.954944 ), Quat( 0.0851365, 0.0745735, -0.186007, 0.976008 ), Quat( 0.0345697, -0.00183333, 0.175622, 0.983849 ), Quat( -0.0263425, -0.00263059, 0.172663, 0.984625 ), Quat( -0.0164912, -0.0258961, 0.00817259, 0.999495 ), Quat( -0.0249918, -0.0351505, 0.486862, 0.872413 ), Quat( -0.0128632, 0.000383946, 0.390856, 0.920362 ), Quat( -0.0608747, 0.00747798, 0.183681, 0.981071 ), Quat( -0.0622974, -0.0814373, 0.164758, 0.98099 ), Quat( -0.0394571, 0.00705154, 0.29538, 0.954539 ), Quat( -0.00836909, 0.0295813, 0.0795284, 0.996359 ), Quat( -0.207036, -0.140343, 0.0183118, 0.968042 ), Quat( 0.0996507, -0.0809182, -0.0547796, 0.990213 ), Quat( -0.0525219, -0.0355324, 0.162446, 0.984678 ), Quat( 0.00073414, 0.049166, 0.0018408, 0.998789 ), Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ) ],
	"handokay11":[ Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ), Quat( 0.468796, 0.370465, 0.0796873, 0.797894 ), Quat( 0.253679, 0.133886, 0.154121, 0.945499 ), Quat( -0.0801607, -0.0425963, 0.294025, 0.951477 ), Quat( 0.0844133, 0.0694556, -0.115931, 0.987224 ), Quat( 0.0989639, 0.0962944, 0.510129, 0.848942 ), Quat( -0.0260832, 0.0018412, 0.333878, 0.942254 ), Quat( -0.0164311, -0.0260999, -0.00417691, 0.999516 ), Quat( -0.0169925, -0.0204683, 0.465035, 0.884892 ), Quat( -0.012763, -0.000259974, 0.341157, 0.93992 ), Quat( -0.0658786, 0.00995623, 0.240274, 0.968416 ), Quat( -0.0853593, -0.116181, 0.31502, 0.938071 ), Quat( -0.0389637, 0.00595738, 0.263555, 0.963839 ), Quat( -0.0110353, 0.0296643, 0.136986, 0.990067 ), Quat( -0.207036, -0.140343, 0.0183118, 0.968042 ), Quat( 0.103993, -0.123004, -0.0700513, 0.984453 ), Quat( -0.0584458, -0.0319938, 0.236702, 0.969295 ), Quat( 0.000860983, 0.0491022, 0.038777, 0.99804 ), Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ) ]
}
var currentgesture = "none"

var pointermodel = null
var pointervalid = false
var pointerposearvrorigin = Transform()
var pointermaterial = null
var pointerposechangeangle = Transform(Basis(Vector3(1,0,0), deg2rad(-65)), Vector3(0,0,0))

const fadetimevalidity = 1/0.2
var handtranslucentvalidity = 0.0
var pointertranslucentvalidity = 0.0

var handpositionstack = [ ]  # [ { "Ltimestamp", "valid", "transform", "boneorientations" } ] 

func _ready():
	islefthand = (get_name() == "HandLeft")
	controllerhandtransform = Transform(Vector3(0,0,-1), Vector3(0,-1,0), Vector3(-1,0,0), Vector3(0,0,0.1)) if islefthand else \
							  Transform(Vector3(0,0,1), Vector3(0,1,0), Vector3(-1,0,0), Vector3(0,0,0.1))
	transform = controllerhandtransform
	var handmodelfile = handmodelfile1 if islefthand else handmodelfile2
	var handmodelres = load(handmodelfile)
	if handmodelres == null:
		print("Please download the Godol Oculus Mobile Plugin: https://github.com/GodotVR/godot-oculus-mobile-asset")
	handmodel = handmodelres.instance()
	add_child(handmodel)
	#handmodel.translation = Vector3(-0.2 if islefthand else 0.2, 0.8, 0)
	handarmature = handmodel.get_child(0)
	handskeleton = handarmature.get_node("Skeleton")
	for i in range(0, handskeleton.get_bone_count()):
		var bone_rest = handskeleton.get_bone_rest(i)
		#print(i, "++++", var2str(bone_rest))
		handskeleton.set_bone_pose(i, Transform(bone_rest.basis)); # use the original rest as pose
		bone_rest.basis = Basis()
		handskeleton.set_bone_rest(i, bone_rest)
	meshnode = handskeleton.get_node("l_handMeshNode" if islefthand else "r_handMeshNode")
	handmaterial = load("res://shinyhandmesh.material").duplicate()
	handmaterial.albedo_color = "#21db2c" if islefthand else "#db212c"
	meshnode.set_surface_material(0, handmaterial)
	pointermodel = load("res://LaserPointer.tscn").instance()
	pointermaterial = pointermodel.get_node("Length/MeshInstance").get_surface_material(0).duplicate()
	pointermodel.get_node("Length/MeshInstance").set_surface_material(0, pointermaterial)
	add_child(pointermodel)
	indexfingerpinchbutton = addfingerpinchbutton("index_null")
	middlefingerpinchbutton = addfingerpinchbutton("middle_null")

func addfingerpinchbutton(bname):
	var boneattachment = BoneAttachment.new()
	boneattachment.bone_name = ("b_l_" if islefthand else "b_r_") + bname
	handskeleton.add_child(boneattachment)
	var fingerpinchbutton = load("res://nodescenes/FingerPinchButton.tscn").instance()
	var handmodelscale = meshnode.global_transform.basis.get_scale()
	fingerpinchbutton.scale = Vector3(1/handmodelscale.x, 1/handmodelscale.y, 1/handmodelscale.z)
	if islefthand:
		fingerpinchbutton.get_node("MeshInstance").transform.origin *= -1
	fingerpinchbutton.get_node("MeshInstance").set_surface_material(0, fingerpinchbutton.get_node("MeshInstance").get_surface_material(0).duplicate())
	boneattachment.add_child(fingerpinchbutton)
	return fingerpinchbutton
	
func initovrhandtracking(lovr_hand_tracking, lhandcontroller):
	handpositionstack = null
	ovr_hand_tracking = lovr_hand_tracking
	handcontroller = lhandcontroller
	controller_id = handcontroller.controller_id
	handscale = ovr_hand_tracking.get_hand_scale(controller_id)
	if handscale > 0:
		handmodel.scale = Vector3(handscale, handscale, handscale)
	handmaterial.albedo_color.a = 0.4
	handmodel.visible = false
	handmaterial.flags_transparent = true


func update_handpose(delta):
	if handvalid:
		for i in range(hand_bone_mappings.size()):
			handskeleton.set_bone_pose(hand_bone_mappings[i], Transform(hand_boneorientations[i]))

func update_fademode(delta, valid, translucentvalidity, model, material):
	if valid:
		if translucentvalidity == 0:
			model.visible = true
		if translucentvalidity < 1:
			translucentvalidity += delta*fadetimevalidity
			if translucentvalidity < 1:
				material.albedo_color.a = translucentvalidity
			else:
				translucentvalidity = 1
				material.flags_transparent = false
	else:
		if translucentvalidity == 1:
			material.flags_transparent = true
		if translucentvalidity > 0:
			translucentvalidity -= delta*fadetimevalidity
			if translucentvalidity > 0:
				material.albedo_color.a = translucentvalidity
			else:
				translucentvalidity = 0
				model.visible = false
	return translucentvalidity
	
func addremotetransform(bname, node, rtransform):
	var boneattachment = BoneAttachment.new()
	boneattachment.bone_name = ("b_l_" if islefthand else "b_r_") + bname
	handskeleton.add_child(boneattachment)
	var remotetransform = RemoteTransform.new()
	remotetransform.update_scale = false
	remotetransform.transform = rtransform
	boneattachment.add_child(remotetransform)
	remotetransform.remote_path = remotetransform.get_path_to(node)

var timeoffset = -0.2
# [ { "timestamp", "valid", "transform", "boneorientations" } ] 
func process_handpositionstack(delta):
	var t = OS.get_ticks_msec()*0.001
	while len(handpositionstack) >= 2 and handpositionstack[1]["Ltimestamp"] <= t:
		handpositionstack.pop_front()
	if len(handpositionstack) == 0 or t < handpositionstack[0]["Ltimestamp"]:
		return
	var hp = handpositionstack[0]
	if len(handpositionstack) == 1:
		if hp.has("valid"):
			handvalid = hp["valid"]
		if hp.has("transform"):
			transform = hp["transform"]
		if hp.has("boneorientations"):
			for i in range(hand_bone_mappings.size()):
				hand_boneorientations[i] = hp["boneorientations"][i]
		handpositionstack.pop_front()
	else:
		var hp1 = handpositionstack[1]
		var lam = inverse_lerp(hp["Ltimestamp"], hp1["Ltimestamp"], t)
		if hp.has("valid") and hp1.has("valid"):
			handvalid = hp["valid"] if lam < 0.5 else hp1["valid"]
		if hp.has("transform") and hp1.has("transform"):
			transform = Transform(hp["transform"].basis.slerp(hp1["transform"].basis, lam), lerp(hp["transform"].origin, hp1["transform"].origin, lam))
		if hp.has("boneorientations") and hp1.has("boneorientations"):
			for i in range(hand_bone_mappings.size()):
				hand_boneorientations[i] = hp["boneorientations"][i].slerp(hp1["boneorientations"][i], lam)
			hp = hp1
	if hp.has("triggerbuttonheld"): 
		indexfingerpinchbutton.get_node("MeshInstance").get_surface_material(0).emission_energy = 1 if hp["triggerbuttonheld"] else 0
	if hp.has("gripbuttonheld"): 
		middlefingerpinchbutton.get_node("MeshInstance").get_surface_material(0).emission_energy = 1 if hp["gripbuttonheld"] else 0
	update_handpose(delta)

func handpositiondict(t0):
	var handposdict = { "timestamp":t0, 
						"valid":handvalid, 
						"transform":transform, 
						"gripbuttonheld":int(gripbuttonheld), 
						"triggerbuttonheld":int(triggerbuttonheld)
					  }
	if true or Tglobal.questhandtracking:
		handposdict["boneorientations"] = hand_boneorientations
	return handposdict

func handposeimmediate(boneorientations, dt):
	handpositionstack.clear()
	var t0 = OS.get_ticks_msec()*0.001
	handpositionstack.push_back({"Ltimestamp":t0, "valid":true, "boneorientations":hand_boneorientations.duplicate() })
	handpositionstack.push_back({"Ltimestamp":t0+dt, "valid":true, "boneorientations":boneorientations })

func initkeyboardtracking():
	handpositionstack = [ ]
	handcontroller = null
	process_handgesturefromcontrol()

func initnormalvrtracking(lhandcontroller):
	handpositionstack = [ ]
	handcontroller = lhandcontroller

func initpuppetracking(lplayerishandtracked):
	print("initpuppetracking: ", lplayerishandtracked, " ", islefthand)
	handpositionstack = [ ]
	playerishandtracked = lplayerishandtracked

func process_ovrhandtracking(delta):
	handconfidence = ovr_hand_tracking.get_hand_pose(controller_id, hand_boneorientations)
	handvalid = handconfidence != null and handconfidence == 1
	if handvalid:
		transform = handcontroller.transform 
		gripbuttonheld = handcontroller.is_button_pressed(BUTTONS.HT_PINCH_MIDDLE_FINGER)
		triggerbuttonheld = handcontroller.is_button_pressed(BUTTONS.HT_PINCH_INDEX_FINGER)
	indexfingerpinchbutton.get_node("MeshInstance").get_surface_material(0).emission_energy = 1 if triggerbuttonheld else (handcontroller.get_joystick_axis(0)+1)/3
	middlefingerpinchbutton.get_node("MeshInstance").get_surface_material(0).emission_energy = 1 if gripbuttonheld else (handcontroller.get_joystick_axis(1)+1)/3
	update_handpose(delta)
	pointervalid = handvalid and ovr_hand_tracking.is_pointer_pose_valid(controller_id)
	if pointervalid:
		pointerposearvrorigin = ovr_hand_tracking.get_pointer_pose(controller_id)  # should this be inverted
		
func process_normalvrtracking(delta):
	joypos = Vector2(handcontroller.get_joystick_axis(0), handcontroller.get_joystick_axis(1))
	gripbuttonheld = handcontroller.is_button_pressed(BUTTONS.VR_GRIP)
	triggerbuttonheld = handcontroller.is_button_pressed(BUTTONS.VR_TRIGGER)
	transform = handcontroller.transform*controllerhandtransform
	pointervalid = true
	pointerposearvrorigin = handcontroller.transform*pointerposechangeangle
	indexfingerpinchbutton.get_node("MeshInstance").get_surface_material(0).emission_energy = 1 if triggerbuttonheld else 0
	middlefingerpinchbutton.get_node("MeshInstance").get_surface_material(0).emission_energy = 1 if gripbuttonheld else 0
	process_handgesturefromcontrol()

func process_keyboardcontroltracking(headcam, dmousecontrollermotioncumulative):
	mousecontrollermotioncumulative = Vector2(clamp(mousecontrollermotioncumulative.x + dmousecontrollermotioncumulative.x, -1.0, 1.0), 
											  clamp(mousecontrollermotioncumulative.y + dmousecontrollermotioncumulative.y, -1.0, 1.0))
	var ht = headcam.transform
	ht = ht*Transform().rotated(Vector3(1,0,0), deg2rad(-mousecontrollermotioncumulative.y*30))*Transform().rotated(Vector3(0,1,0), deg2rad(-mousecontrollermotioncumulative.x*50-10))
	ht.origin += -0.5*ht.basis.z
	pointervalid = true
	ht = ht*Transform().rotated(Vector3(1,0,0), deg2rad(45))*Transform().rotated(Vector3(0,1,0), deg2rad(30))
	transform = ht*controllerhandtransform
	pointerposearvrorigin = ht*pointerposechangeangle # *Transform().rotated(Vector3(0,1,0), deg2rad(90))
	indexfingerpinchbutton.get_node("MeshInstance").get_surface_material(0).emission_energy = 1 if triggerbuttonheld else 0
	middlefingerpinchbutton.get_node("MeshInstance").get_surface_material(0).emission_energy = 1 if gripbuttonheld else 0
	process_handgesturefromcontrol()	

func process_handgesturefromcontrol():
	var newcurrentgesture = "handokay" + ("1" if triggerbuttonheld else "0") + ("1" if gripbuttonheld else "0")
	if newcurrentgesture != currentgesture:
		currentgesture = newcurrentgesture
		handposeimmediate(gestureboneorientations[currentgesture], 0.2)
	
func _process(delta):
	if handpositionstack != null and len(handpositionstack) != 0:
		process_handpositionstack(delta)
	handtranslucentvalidity = update_fademode(delta, handvalid, handtranslucentvalidity, handmodel, handmaterial)
	if pointervalid:
		pointermodel.transform = transform.inverse()*pointerposearvrorigin
	pointertranslucentvalidity = update_fademode(delta, pointervalid, pointertranslucentvalidity, pointermodel, pointermaterial)

