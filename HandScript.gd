extends Spatial

const hand_bone_mappings = [0, 23,  1, 2, 3, 4,  6, 7, 8,  10, 11, 12,  14, 15, 16, 18, 19, 20, 21];
var ovrhandLRrestdata = null
var islefthand = false
var handcontroller = null
var handposecontroller = null
var controller_id = 0
var OpenXRallhandsdata = null

var controllermodel = null
var controllermodel_trigger = null
var controllermodel_grip = null
var controllermodel_by = null

var handmodel = null
var handarmature = null
var handskeleton = null
var meshnode = null
var handmaterial = null
var handmaterial_orgtransparency = false
var handmaterial_orgtranslucency = 1.0

var joypos = Vector2(0, 0)

var controllerhandtransform = null
func setcontrollerhandtransform(playerscale):
	if islefthand:
		controllerhandtransform = Transform(Basis(Vector3(0,0,1), deg2rad(45*0)), Vector3(0,0,0)) * \
								  Transform(Vector3(0,0,-1), Vector3(0,-1,0), Vector3(-1,0,0), Vector3(0,0,0.1*playerscale))
	else:
		controllerhandtransform = Transform(Basis(Vector3(0,0,1), deg2rad(-45*0)), Vector3(0,0,0)) * \
								  Transform(Vector3(0,0,1), Vector3(0,1,0), Vector3(-1,0,0), Vector3(0,0,0.1*playerscale))
	handmodel.scale = Vector3(1,1,1)*playerscale*ovrhandscale
	controllermodel.scale = Vector3(1,1,1)*playerscale
	if has_node("HandFlickFaceY"):
		$HandFlickFaceY.scale = Vector3(1,1,1)*playerscale
	
var mousecontrollermotioncumulative = Vector2(0, 0)
var gripbuttonheld := false
var triggerbuttonheld = false
var vrbybuttonheld = false
var vrpadbuttonheld = false
var indexfingerpinchbutton = null
var middlefingerpinchbutton = null
var middleringbutton = null

var ovrhandscale = 1.0
var handconfidence = 0
enum { HS_INVALID=0, HS_HAND=1, HS_TOUCHCONTROLLER=2 }
var handstate = HS_INVALID
var hand_boneorientations = [ Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ), Quat( 0.467562, 0.371268, 0.0784822, 0.798365 ), Quat( 0.253112, 0.141304, 0.155991, 0.944264 ), Quat( -0.0820883, -0.0530134, 0.190872, 0.976739 ), Quat( 0.0813293, 0.0570069, 0.0396865, 0.994264 ), Quat( 0.0443113, 0.0529943, 0.211373, 0.974961 ), Quat( -0.0262251, 0.000635884, 0.291161, 0.956315 ), Quat( -0.0167604, -0.0247861, 0.0716335, 0.996982 ), Quat( -0.0144094, -0.0484558, 0.17288, 0.983645 ), Quat( -0.0127633, -0.000258344, 0.341284, 0.939874 ), Quat( -0.0484786, 0.00163537, 0.0500899, 0.997566 ), Quat( -0.0682813, -0.113321, 0.185936, 0.973614 ), Quat( -0.0401938, 0.00888745, 0.348554, 0.936384 ), Quat( -0.0114638, 0.0296684, 0.146252, 0.988736 ), Quat( -0.207036, -0.140343, 0.0183118, 0.968042 ), Quat( 0.0544313, -0.108607, 0.254061, 0.959528 ), Quat( -0.0522058, -0.0357106, 0.158563, 0.985321 ), Quat( 0.00130541, 0.0483228, 0.170572, 0.984159 ), Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ) ]

const gestureboneorientations = { 
	"handthumbfings0000":[ Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ), Quat( 0.467562, 0.371268, 0.0784822, 0.798365 ), Quat( 0.253112, 0.141304, 0.155991, 0.944264 ), Quat( -0.0820883, -0.0530134, 0.190872, 0.976739 ), Quat( 0.0813293, 0.0570069, 0.0396865, 0.994264 ), Quat( 0.0443113, 0.0529943, 0.211373, 0.974961 ), Quat( -0.0262251, 0.000635884, 0.291161, 0.956315 ), Quat( -0.0167604, -0.0247861, 0.0716335, 0.996982 ), Quat( -0.0144094, -0.0484558, 0.17288, 0.983645 ), Quat( -0.0127633, -0.000258344, 0.341284, 0.939874 ), Quat( -0.0484786, 0.00163537, 0.0500899, 0.997566 ), Quat( -0.0682813, -0.113321, 0.185936, 0.973614 ), Quat( -0.0401938, 0.00888745, 0.348554, 0.936384 ), Quat( -0.0114638, 0.0296684, 0.146252, 0.988736 ), Quat( -0.207036, -0.140343, 0.0183118, 0.968042 ), Quat( 0.0544313, -0.108607, 0.254061, 0.959528 ), Quat( -0.0522058, -0.0357106, 0.158563, 0.985321 ), Quat( 0.00130541, 0.0483228, 0.170572, 0.984159 ), Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ) ],
	"handthumbfings1000":[ Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ), Quat( 0.492735, 0.354362, 0.103353, 0.788009 ), Quat( 0.256355, 0.0956267, 0.144365, 0.950945 ), Quat( -0.0816594, -0.0502562, 0.218979, 0.971007 ), Quat( 0.084894, 0.0725345, -0.157577, 0.981173 ), Quat( 0.0949116, 0.100794, 0.477651, 0.867572 ), Quat( -0.0261218, 0.00155448, 0.323766, 0.945775 ), Quat( -0.0169196, -0.0238768, 0.119608, 0.99239 ), Quat( -0.00877956, -0.00536436, 0.174319, 0.984636 ), Quat( -0.011972, -0.00288329, 0.127877, 0.991714 ), Quat( -0.0344616, -0.00455115, -0.0916157, 0.995188 ), Quat( -0.0491183, -0.0784361, -0.0137709, 0.995613 ), Quat( -0.0364712, 0.00137097, 0.129095, 0.99096 ), Quat( -0.00430107, 0.0292692, -0.00750024, 0.999534 ), Quat( -0.207036, -0.140343, 0.0183118, 0.968042 ), Quat( 0.105822, -0.0387376, -0.140094, 0.983705 ), Quat( -0.0454153, -0.0393059, 0.0768608, 0.995231 ), Quat( 0.000672678, 0.0491727, -0.0159533, 0.998663 ), Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ) ],
	"handthumbfings0100":[ Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ), Quat( 0.511247, 0.341179, 0.122062, 0.77931 ), Quat( 0.253986, 0.129789, 0.153086, 0.946156 ), Quat( -0.0804297, -0.0438226, 0.282298, 0.954944 ), Quat( 0.0851365, 0.0745735, -0.186007, 0.976008 ), Quat( 0.0345697, -0.00183333, 0.175622, 0.983849 ), Quat( -0.0263425, -0.00263059, 0.172663, 0.984625 ), Quat( -0.0164912, -0.0258961, 0.00817259, 0.999495 ), Quat( -0.0249918, -0.0351505, 0.486862, 0.872413 ), Quat( -0.0128632, 0.000383946, 0.390856, 0.920362 ), Quat( -0.0608747, 0.00747798, 0.183681, 0.981071 ), Quat( -0.0622974, -0.0814373, 0.164758, 0.98099 ), Quat( -0.0394571, 0.00705154, 0.29538, 0.954539 ), Quat( -0.00836909, 0.0295813, 0.0795284, 0.996359 ), Quat( -0.207036, -0.140343, 0.0183118, 0.968042 ), Quat( 0.0996507, -0.0809182, -0.0547796, 0.990213 ), Quat( -0.0525219, -0.0355324, 0.162446, 0.984678 ), Quat( 0.00073414, 0.049166, 0.0018408, 0.998789 ), Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ) ],
	"handthumbfings1100":[ Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ), Quat( 0.484506, 0.360013, 0.0951526, 0.791575 ), Quat( 0.252582, 0.148047, 0.157683, 0.943091 ), Quat( -0.0814613, -0.0490986, 0.230602, 0.968388 ), Quat( 0.0831999, 0.0637273, -0.0420198, 0.993605 ), Quat( 0.0467705, -0.00912709, 0.580274, 0.813026 ), Quat( -0.0263272, -0.00309788, 0.155384, 0.987499 ), Quat( -0.0166674, -0.025214, 0.0478704, 0.998396 ), Quat( -0.037304, -0.0527957, 0.529854, 0.845622 ), Quat( -0.012807, -5.6843e-06, 0.360906, 0.932514 ), Quat( -0.0582168, 0.00619166, 0.154289, 0.98629 ), Quat( -0.0754809, -0.129617, 0.223067, 0.963194 ), Quat( -0.0370004, 0.00224887, 0.154962, 0.987225 ), Quat( -0.00615023, 0.0294384, 0.0319656, 0.999036 ), Quat( -0.207036, -0.140343, 0.0183118, 0.968042 ), Quat( 0.132813, -0.122201, -0.222284, 0.958132 ), Quat( -0.0482045, -0.0378814, 0.110032, 0.992035 ), Quat( 0.000892593, 0.0490757, 0.048027, 0.997639 ), Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ) ],
	"handthumbfings0011":[ Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ), Quat( 0.565494, 0.298331, 0.179247, 0.74772 ), Quat( 0.257287, 0.0806693, 0.140499, 0.952657 ), Quat( -0.0805482, -0.0443792, 0.27694, 0.956476 ), Quat( 0.0847294, 0.0713815, -0.141809, 0.983675 ), Quat( 0.0501409, 0.0960369, 0.205655, 0.972609 ), Quat( -0.0263111, -0.00343488, 0.142871, 0.989386 ), Quat( -0.0164633, -0.0259923, 0.00237251, 0.999524 ), Quat( -0.00840722, -0.00229804, 0.156678, 0.987611 ), Quat( -0.0124486, -0.00156159, 0.237535, 0.971298 ), Quat( -0.0491014, 0.00191996, 0.0566024, 0.997187 ), Quat( -0.0631587, -0.0266687, 0.37522, 0.924397 ), Quat( -0.0410564, 0.0115732, 0.425805, 0.903809 ), Quat( -0.0147374, 0.0296123, 0.21734, 0.975535 ), Quat( -0.207036, -0.140343, 0.0183118, 0.968042 ), Quat( 0.122949, 0.0889387, 0.454647, 0.87765 ), Quat( -0.0646035, -0.0278637, 0.317238, 0.945733 ), Quat( 0.000930573, 0.0490382, 0.0591654, 0.997043 ), Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ), Quat( 0, 0, 0, 1 ) ]
}
var currentgesture = "none"

var pointermodel = null
var pointervalid = false
var controllerpointerposetransform = Transform(Basis(Vector3(1,0,0), deg2rad(-65)), Vector3(0,0,0))
var pointerposearvrorigin = Transform()
var pointermaterial = null

var internalhandray = null
var boneattachmentwrist = null
var boneattachmentmiddletip = null

const fadetimevalidity = 1/0.2
var handtranslucentvalidity = 0.0
var pointertranslucentvalidity = 0.0

var handpositionstack = [ ]  # [ { "Ltimestamp", "valid", "transform", "boneorientations" } ] 

func _ready():
	islefthand = (get_name() == "HandLeft")
	controllermodel = get_node("OculusQuestTouchController_Left_Reactive" if islefthand else "OculusQuestTouchController_Right_Reactive")
	controllermodel_trigger = controllermodel.get_node("l_controller_Trigger") if islefthand else controllermodel.get_node("r_controller_Trigger")
	controllermodel_grip = controllermodel.get_node("l_controller_Grip") if islefthand else controllermodel.get_node("r_controller_Grip")
	controllermodel_by = controllermodel.get_node("l_controller_Y") if islefthand else controllermodel.get_node("r_controller_B")
	var controllermaterial = controllermodel_trigger.mesh.surface_get_material(0)  # no idea how this is already getting set
	controllermaterial.set_texture(SpatialMaterial.TEXTURE_ALBEDO, load("res://assets/ovrmodels/OculusQuestTouchControllerTexture_Color_inverted.png"))
	var controllertriggermaterial = controllermodel_trigger.mesh.surface_get_material(0)
	controllertriggermaterial = controllertriggermaterial.duplicate()
	controllertriggermaterial.albedo_color = Color(1.0, 0.5, 0.0)
	controllermodel_trigger.mesh.surface_set_material(0, controllertriggermaterial)

	var controllergripmaterial = controllermodel_grip.mesh.surface_get_material(0)
	controllergripmaterial = controllergripmaterial.duplicate()
	controllergripmaterial.albedo_color = Color(0.5, 1.0, 0.5)
	controllermodel_grip.mesh.surface_set_material(0, controllergripmaterial)
	
	handmodel = get_node("left_hand_model" if islefthand else "right_hand_model")
	setcontrollerhandtransform(1.0)
	transform = controllerhandtransform
	handarmature = handmodel.get_child(0)
	handskeleton = handarmature.get_node("Skeleton")

	print("reset the hand bone rests (for the original OVR functioning) bwhenrestisreset")
	for i in range(0, handskeleton.get_bone_count()):
		var bone_rest = handskeleton.get_bone_rest(i)
		handskeleton.set_bone_pose(i, Transform(bone_rest.basis)); # use the original rest as pose
		bone_rest.basis = Basis()
		handskeleton.set_bone_rest(i, bone_rest)
		
	meshnode = handskeleton.get_node("l_handMeshNode" if islefthand else "r_handMeshNode")
	#handmaterial = load("res://shinyhandmesh.material").duplicate()
	var handmaterials = get_node("/root/Spatial/MaterialSystem/handmaterials")
	handmaterial = handmaterials.get_node("handleft" if islefthand else "handright").get_surface_material(0).duplicate()
	meshnode.set_surface_material(0, handmaterial)
	handmaterial_orgtransparency = handmaterial.flags_transparent
	handmaterial_orgtranslucency = handmaterial.albedo_color.a
	
	pointermodel = load("res://LaserPointer.tscn").instance()
	pointermaterial = pointermodel.get_node("Length/MeshInstance").get_surface_material(0).duplicate()
	pointermodel.get_node("Length/MeshInstance").set_surface_material(0, pointermaterial)
	add_child(pointermodel)
	pointermodel.visible = false
	if not islefthand:
		pointermodel.get_node("Length").visible = false

	indexfingerpinchbutton = addfingerpinchbutton("index_null")
	middlefingerpinchbutton = addfingerpinchbutton("middle_null")
	if has_node("RayCast"):
		middleringbutton = addfingerpinchbutton("middle_1")
		middleringbutton.get_node("MeshInstance").transform.origin.y *= -2
		internalhandray = $RayCast
		boneattachmentmiddletip = addboneattachment("middle_null")
	
func addfingerpinchbutton(bname):
	var boneattachment = addboneattachment(bname)
	var fingerpinchbutton = load("res://nodescenes/FingerPinchButton.tscn").instance()
	var handmodelscale = meshnode.global_transform.basis.get_scale()
	fingerpinchbutton.scale = Vector3(1/handmodelscale.x, 1/handmodelscale.y, 1/handmodelscale.z)
	if islefthand:
		fingerpinchbutton.get_node("MeshInstance").transform.origin *= -1
	fingerpinchbutton.get_node("MeshInstance").set_surface_material(0, fingerpinchbutton.get_node("MeshInstance").get_surface_material(0).duplicate())
	boneattachment.add_child(fingerpinchbutton)
	fingerpinchbutton.set_name(bname)
	fingerpinchbutton.visible = true
	return fingerpinchbutton
	
func initovrhandtracking(lhandcontroller, lhandposecontroller, lovrhandLRrestdata):
	controllerpointerposetransform = Transform(Basis(Vector3(1,0,0), deg2rad(-65)), Vector3(0,0,0))
	ovrhandLRrestdata = lovrhandLRrestdata
	handcontroller = lhandcontroller
	handposecontroller = lhandposecontroller
	OpenXRallhandsdata = get_parent().get_node_or_null("OpenXRallhandsdata")
	controller_id = handcontroller.controller_id
	var lovrhandscale = 1.0 # ovr_hand_tracking.get_hand_scale(controller_id)
	if lovrhandscale > 0:
		ovrhandscale = lovrhandscale
	handmodel.scale = Vector3(ovrhandscale, ovrhandscale, ovrhandscale)
	handmaterial.albedo_color.a = 0.4
	handmodel.visible = false
	handmaterial.flags_transparent = true

func update_handpose(delta):
	if handstate == HS_HAND:
		for i in range(hand_bone_mappings.size()):
			handskeleton.set_bone_pose(hand_bone_mappings[i], Transform(hand_boneorientations[i]))

		if internalhandray != null:
			var tipfinger = boneattachmentmiddletip.global_transform*Vector3(-1, 0, 0) # factored up with handmodelscale=0.01
			var wristpos = global_transform
			internalhandray.global_transform = wristpos.looking_at(tipfinger, Vector3(0,1,0))
			internalhandray.cast_to.z = -wristpos.origin.distance_to(tipfinger)
			internalhandray.enabled = true
	else:
		if internalhandray != null:
			internalhandray.enabled = false

func update_fademode(delta, valid, translucentvalidity, model, material):
	if valid:
		model.visible = true
		if translucentvalidity < 1:
			translucentvalidity += delta*fadetimevalidity
			if translucentvalidity < 1:
				material.albedo_color.a = translucentvalidity*handmaterial_orgtranslucency
			else:
				translucentvalidity = 1
				material.albedo_color.a = handmaterial_orgtranslucency
				material.flags_transparent = handmaterial_orgtransparency
	else:
		if translucentvalidity == 1:
			material.flags_transparent = true
		if translucentvalidity > 0:
			translucentvalidity -= delta*fadetimevalidity
			if translucentvalidity > 0:
				material.albedo_color.a = translucentvalidity*handmaterial_orgtranslucency
			else:
				translucentvalidity = 0
				model.visible = false
	return translucentvalidity
	
func addboneattachment(bname):
	var boneattachment = BoneAttachment.new()
	boneattachment.bone_name = ("b_l_" if islefthand else "b_r_") + bname
	handskeleton.add_child(boneattachment)
	boneattachment.set_name(bname)
	return boneattachment

func addremotetransform(bname, node, rtransform):
	var boneattachment =  addboneattachment(bname)
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
		if hp.has("handstate"):
			handstate = hp["handstate"]
		elif hp.has("valid"):
			handstate = HS_HAND if hp["valid"] else HS_INVALID
		if hp.has("transform"):
			transform = hp["transform"]
		if hp.has("boneorientations"):
			for i in range(hand_bone_mappings.size()):
				hand_boneorientations[i] = hp["boneorientations"][i]
		if hp.has("controllerbuttons"):
			controllermodel_trigger.rotation_degrees.x = hp["controllerbuttons"]["trigger"]
			controllermodel_grip.transform.origin.x = hp["controllerbuttons"]["grip"]
			controllermodel_by.transform.origin.y = hp["controllerbuttons"]["by"]

		handpositionstack.pop_front()
	else:
		var hp1 = handpositionstack[1]
		var lam = inverse_lerp(hp["Ltimestamp"], hp1["Ltimestamp"], t)
		if hp.has("handstate") and hp1.has("handstate"):
			handstate = hp["handstate"] if lam < 0.5 else hp1["handstate"]
		elif hp.has("valid") and hp1.has("valid"):
			handstate = HS_HAND if (hp["valid"] if lam < 0.5 else hp1["valid"]) else HS_INVALID

		if hp.has("transform") and hp1.has("transform"):
			transform = Transform(hp["transform"].basis.slerp(hp1["transform"].basis, lam), lerp(hp["transform"].origin, hp1["transform"].origin, lam))
		if hp.has("controllerbuttons"):
			controllermodel_trigger.rotation_degrees.x = lerp(hp["controllerbuttons"]["trigger"], hp1["controllerbuttons"]["trigger"], lam)
			controllermodel_grip.transform.origin.x = lerp(hp["controllerbuttons"]["grip"], hp1["controllerbuttons"]["grip"], lam)
			controllermodel_by.transform.origin.y = lerp(hp["controllerbuttons"]["by"], hp1["controllerbuttons"]["by"], lam)
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
						"valid":(handstate != HS_INVALID), # to delete
						"handstate":handstate,
						"transform":transform, 
						"gripbuttonheld":int(gripbuttonheld), 
						"triggerbuttonheld":int(triggerbuttonheld),
						"vrbybuttonheld":int(vrbybuttonheld),
						"controllerbuttons":{"trigger":controllermodel_trigger.rotation_degrees.x, 
											 "grip":controllermodel_grip.transform.origin.x,
											 "by":controllermodel_by.transform.origin.y}
					  }
	if true or Tglobal.questhandtracking:
		handposdict["boneorientations"] = hand_boneorientations
	return handposdict

func handposeimmediate(boneorientations, dt):
	handpositionstack.clear()
	var t0 = OS.get_ticks_msec()*0.001
	handpositionstack.push_back({"Ltimestamp":t0, 
								 "valid":true, 
								 "handstate":handstate,
								 "boneorientations":hand_boneorientations.duplicate(), 
								 "controllerbuttons":{ "trigger":controllermodel_trigger.rotation_degrees.x, 
													   "grip":controllermodel_grip.transform.origin.x,
													   "by":controllermodel_by.transform.origin.y }
							   })
	handpositionstack.push_back({"Ltimestamp":t0+dt, 
								 "valid":true, 
								 "handstate":handstate,
								 "boneorientations":boneorientations,
								 "controllerbuttons":{ "trigger":(25.0 if islefthand else -25.0) if triggerbuttonheld else 0.0, 
													   "grip":(-0.0035 if islefthand else 0.0035) if gripbuttonheld else 0.0,
													   "by":-0.002 if vrbybuttonheld else 0.0 }
							   })

func initnormalvrtracking(lhandcontroller):
	handcontroller = lhandcontroller


func process_ovrhandtracking(delta):
	handpositionstack.clear()
	var handconfidence = OpenXRallhandsdata.palm_joint_confidence_L if islefthand else OpenXRallhandsdata.palm_joint_confidence_R
	var joint_transforms = OpenXRallhandsdata.joint_transforms_L if islefthand else OpenXRallhandsdata.joint_transforms_R
	if handconfidence == OpenXRallhandsdata.TRACKING_CONFIDENCE_HIGH:
		var ovrhandpose = OpenXRtrackedhand_funcs.setshapetobonesOVR(joint_transforms, ovrhandLRrestdata)
		for i in range(hand_bone_mappings.size()):
			var ib = hand_bone_mappings[i]
			if ib != 23:
				hand_boneorientations[i] = (ovrhandLRrestdata[ib].basis*ovrhandpose[ib].basis).get_rotation_quat()

		handstate = HS_HAND
		transform = ovrhandpose["handtransform"] 
		gripbuttonheld = handposecontroller.is_button_pressed(BUTTONS.HT_PINCH_MIDDLE_FINGER)
		triggerbuttonheld = handposecontroller.is_button_pressed(BUTTONS.HT_PINCH_INDEX_FINGER)

		OpenXRallhandsdata.triggerpinchedjoyvalue_L if islefthand else OpenXRallhandsdata.triggerpinchedjoyvalue_R

	else:
		if handstate != HS_INVALID:
			print("  *** handstate made invalid...")
		handstate = HS_INVALID
	indexfingerpinchbutton.get_node("MeshInstance").get_surface_material(0).emission_energy = 1 if triggerbuttonheld else (handposecontroller.get_joystick_axis(OpenXRallhandsdata.JOY_AXIS_THUMB_INDEX_PINCH)+1)/3
	middlefingerpinchbutton.get_node("MeshInstance").get_surface_material(0).emission_energy = 1 if gripbuttonheld else (handposecontroller.get_joystick_axis(OpenXRallhandsdata.JOY_AXIS_THUMB_MIDDLE_PINCH)+1)/3
	update_handpose(delta)
	pointervalid = (handstate == HS_HAND) and handposecontroller.get_is_active()
	if pointervalid:
		pointerposearvrorigin = handposecontroller.transform
		
const controllerzdisplacementcorrection = 0.05
func process_normalvrtracking(delta):
	joypos = Vector2(handcontroller.get_joystick_axis(0), handcontroller.get_joystick_axis(1))
	gripbuttonheld = handcontroller.is_button_pressed(BUTTONS.VR_GRIP)
	triggerbuttonheld = handcontroller.is_button_pressed(BUTTONS.VR_TRIGGER)
	vrbybuttonheld = handcontroller.is_button_pressed(BUTTONS.VR_BUTTON_BY)
	vrpadbuttonheld = handcontroller.is_button_pressed(BUTTONS.VR_PAD)
	if handstate == HS_TOUCHCONTROLLER:
		transform = Transform(handcontroller.transform.basis, handcontroller.transform.origin + controllerzdisplacementcorrection*handcontroller.transform.basis.z)
		pointerposearvrorigin = transform * controllerpointerposetransform
	else:
		transform = handcontroller.transform * controllerhandtransform
		pointerposearvrorigin = handcontroller.transform * controllerpointerposetransform
	pointervalid = true
	indexfingerpinchbutton.get_node("MeshInstance").get_surface_material(0).emission_energy = 1 if triggerbuttonheld else 0
	middlefingerpinchbutton.get_node("MeshInstance").get_surface_material(0).emission_energy = 1 if gripbuttonheld else 0
	process_handgesturefromcontrol()

func process_keyboardcontroltracking(headcam, dmousecontrollermotioncumulative, playerscale):
	mousecontrollermotioncumulative = Vector2(clamp(mousecontrollermotioncumulative.x + dmousecontrollermotioncumulative.x, -1.0, 1.0), 
											  clamp(mousecontrollermotioncumulative.y + dmousecontrollermotioncumulative.y, -1.0, 1.0))
	var ht = headcam.transform
	ht = ht*Transform().rotated(Vector3(1,0,0), deg2rad(-mousecontrollermotioncumulative.y*30))*Transform().rotated(Vector3(0,1,0), deg2rad(-mousecontrollermotioncumulative.x*50-10))
	ht.origin += -0.5*playerscale*ht.basis.z
	pointervalid = true
	ht = ht*Transform().rotated(Vector3(1,0,0), deg2rad(45))*Transform().rotated(Vector3(0,1,0), deg2rad(30))
	if handstate == HS_TOUCHCONTROLLER:
		transform = ht
	else:
		transform = ht * controllerhandtransform
	pointerposearvrorigin = ht*controllerpointerposetransform
	indexfingerpinchbutton.get_node("MeshInstance").get_surface_material(0).emission_energy = 1 if triggerbuttonheld else 0
	middlefingerpinchbutton.get_node("MeshInstance").get_surface_material(0).emission_energy = 1 if gripbuttonheld else 0
	process_handgesturefromcontrol()	

func process_handgesturefromcontrol():
	var newcurrentgesture = "handthumbfings0011" if vrbybuttonheld else \
							"handthumbfings" + ("1" if triggerbuttonheld else "0") + ("1" if gripbuttonheld else "0") + "00"
	if newcurrentgesture != currentgesture:
		currentgesture = newcurrentgesture
		handposeimmediate(gestureboneorientations[currentgesture], 0.1 if handstate == HS_TOUCHCONTROLLER else 0.2)
	
func _process(delta):
	if handpositionstack != null and len(handpositionstack) != 0:
		process_handpositionstack(delta)
	if handstate == HS_TOUCHCONTROLLER:
		handmodel.visible = false
		controllermodel.visible = true
	else:
		controllermodel.visible = false
		handtranslucentvalidity = update_fademode(delta, (handstate != HS_INVALID), handtranslucentvalidity, handmodel, handmaterial)
	if pointervalid:
		pointermodel.transform = transform.inverse()*pointerposearvrorigin
	pointertranslucentvalidity = update_fademode(delta, pointervalid, pointertranslucentvalidity, pointermodel, pointermaterial)



	

