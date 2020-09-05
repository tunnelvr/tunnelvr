extends ARVROrigin

var doppelganger = null 

var arvrinterface = null
var networkID = 0
var bouncetestnetworkID = 0
var VRstatus = "unknown"

func setheadtorchlight(torchon):
	$HeadCam/HeadtorchLight.visible = torchon
	get_node("/root/Spatial/WorldEnvironment").environment = preload("res://environments/underground_env.tres") if torchon else preload("res://environments/default_env.tres")
	get_node("/root/Spatial/WorldEnvironment/DirectionalLight").visible = not torchon
	get_node("/root/Spatial/MaterialSystem").adjustmaterialtotorchlight(torchon)
	get_node("/root/Spatial/SketchSystem").get_node("SoundPos1").global_transform.origin = $HeadCam.global_transform.origin + $HeadCam.global_transform.basis.y * 0.2
	get_node("/root/Spatial/SketchSystem").get_node("SoundPos1").play()

func setdoppelganger(doppelgangeron):
	if doppelgangeron:
		if doppelganger == null:
			doppelganger = preload("res://nodescenes/PlayerPuppet.tscn").instance()
			doppelganger.set_name("Doppelganger")
			get_parent().add_child(doppelganger)
		doppelganger.visible = true
		doppelganger.global_transform.origin = $HeadCam.global_transform.origin - 3*Vector3($HeadCam.global_transform.basis.z.x, 0, $HeadCam.global_transform.basis.z.z).normalized()
		
	elif not doppelgangeron and doppelganger != null:
		doppelganger.queue_free()
		doppelganger = null	

func _ready():
	$HandRight/csghandright.setpartcolor(1, "#FFFFFF")
	$HandRight/csghandright.setpartcolor(2, Color("#FFFFFF"))
	$HandLeft/csghandleft.setpartcolor(2, Color("#FFFFFF"))

func _physics_process(_delta):
	pass

remote func setavatarposition(positiondict):
	print("ppt nope not master ", positiondict)

puppet func bouncedoppelgangerposition(bouncebackID, positiondict):
	rpc_unreliable_id(bouncebackID, "setdoppelgangerposition", positiondict)

remotesync func playvoicerecording(wavrecording):
	print("playing recording ", wavrecording.size()) 
	var stream = AudioStreamSample.new()
	stream.format = AudioStreamSample.FORMAT_16_BITS
	stream.data = wavrecording
	stream.mix_rate = 44100
	stream.stereo = true
	$HandLeft/AudioStreamPlayer3D.stream = stream
	$HandLeft/AudioStreamPlayer3D.play()

func playerpositiondict():
	return { "playertransform":global_transform, 
			 "headcamtransform":$HeadCam.transform, 
			 "handlefttransform":$HandLeft.transform if $HandLeft.visible else null, 
			 "handrighttransform":$HandRight.transform if $HandRight.visible else null, 
			 "laserrotation":$HandRight/LaserOrient.rotation.x, 
			 "laserlength":$HandRight/LaserOrient/Length.scale.z, 
			 "laserspot":$HandRight/LaserOrient/LaserSpot.visible, 
			 "timestamp":OS.get_ticks_usec() 
			}


###################
var ovr_hand_tracking = null
var _vrapi_bone_orientations = [];
var _hand_bone_mappings = [0, 23,  1, 2, 3, 4,  6, 7, 8,  10, 11, 12,  14, 15, 16, 18, 19, 20, 21];
var test_pose_left_ThumbsUp = [
	Quat(0, 0, 0, 1), Quat(0, 0, 0, 1), Quat(0.321311, 0.450518, -0.055395, 0.831098),
	Quat(0.263483, -0.092072, 0.093766, 0.955671), Quat(-0.082704, -0.076956, -0.083991, 0.990042),
	Quat(0.085132, 0.074532, -0.185419, 0.976124), Quat(0.010016, -0.068604, 0.563012, 0.823536),
	Quat(-0.019362, 0.016689, 0.8093, 0.586839), Quat(-0.01652, -0.01319, 0.535006, 0.844584),
	Quat(-0.072779, -0.078873, 0.665195, 0.738917), Quat(-0.0125, 0.004871, 0.707232, 0.706854),
	Quat(-0.092244, 0.02486, 0.57957, 0.809304), Quat(-0.10324, -0.040148, 0.705716, 0.699782),
	Quat(-0.041179, 0.022867, 0.741938, 0.668812), Quat(-0.030043, 0.026896, 0.558157, 0.828755),
	Quat(-0.207036, -0.140343, 0.018312, 0.968042), Quat(0.054699, -0.041463, 0.706765, 0.704111),
	Quat(-0.081241, -0.013242, 0.560496, 0.824056), Quat(0.00276, 0.037404, 0.637818, 0.769273),
]

func _clear_bone_rest(skel):
	for i in range(0, skel.get_bone_count()):
		var bone_rest = skel.get_bone_rest(i);
		skel.set_bone_pose(i, Transform(bone_rest.basis)); # use the original rest as pose
		bone_rest.basis = Basis();
		skel.set_bone_rest(i, bone_rest);

func initquesthandtrackingnow(lovr_hand_tracking):
	ovr_hand_tracking = lovr_hand_tracking
	#var lefthandmodel = load("res://addons/godot_ovrmobile/example_scenes/left_hand_model.glb").instance()
	#var righthandmodel = load("res://addons/godot_ovrmobile/example_scenes/right_hand_model.glb").instance()
	#$HandLeft.add_child(lefthandmodel)
	#$HandRight.add_child(righthandmodel)
	$HandLeft/csghandleft.visible = false
	$HandRight/csghandright.visible = false
	$HandLeft/left_hand_model.visible = true
	$HandRight/right_hand_model.visible = true
	
	
	_clear_bone_rest($HandLeft/left_hand_model/ArmatureLeft/Skeleton);
	_clear_bone_rest($HandRight/right_hand_model/ArmatureRight/Skeleton);
	_vrapi_bone_orientations.resize(24);

	
func _update_hand_model(hand: ARVRController, model : Spatial, skel: Skeleton):
	var ls = ovr_hand_tracking.get_hand_scale(hand.controller_id);
	if ls != null and (ls > 0.0):
		model.scale = Vector3(ls, ls, ls);

	var confidence = ovr_hand_tracking.get_hand_pose(hand.controller_id, _vrapi_bone_orientations);
	if confidence != null and (confidence > 0.0):
		model.visible = true;
		for i in range(0, _hand_bone_mappings.size()):
			skel.set_bone_pose(_hand_bone_mappings[i], Transform(_vrapi_bone_orientations[i]));
	else:
		model.visible = false;


var t = 0.0;
func _process(delta_t):
	if ovr_hand_tracking != null:
		_update_hand_model($HandLeft, $HandLeft/left_hand_model, $HandLeft/left_hand_model/ArmatureLeft/Skeleton)
		_update_hand_model($HandRight, $HandRight/right_hand_model, $HandRight/right_hand_model/ArmatureRight/Skeleton)

		t += delta_t;
		if (t > 1.0):
			t = 0.0;
			print("Left Pinches: %.3f %.3f %.3f %.3f; Right Pinches %.3f %.3f %.3f %.3f" %
				 [$HandLeft.get_joystick_axis(0)+1, $HandLeft.get_joystick_axis(1)+1, $HandLeft.get_joystick_axis(2)+1, $HandLeft.get_joystick_axis(3)+1,
				  $HandRight.get_joystick_axis(0)+1, $HandRight.get_joystick_axis(1)+1, $HandRight.get_joystick_axis(2)+1, $HandRight.get_joystick_axis(3)+1]);


