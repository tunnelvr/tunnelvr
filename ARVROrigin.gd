extends ARVROrigin

var doppelganger = null 

var networkID = 0
var bouncetestnetworkID = 0
onready var LaserOrient = get_node("/root/Spatial/BodyObjects/LaserOrient")
var ovr_hand_tracking = null

func setheadtorchlight(torchon):
	$HeadCam/HeadtorchLight.visible = torchon
	get_node("/root/Spatial/WorldEnvironment").environment = preload("res://environments/underground_env.tres") if torchon else preload("res://environments/default_env.tres")
	get_node("/root/Spatial/WorldEnvironment/DirectionalLight").visible = not torchon
	get_node("/root/Spatial/MaterialSystem").adjustmaterialtotorchlight(torchon)
	get_node("/root/Spatial/SoundSystem").quicksound("ClickSound", $HeadCam.global_transform.origin + $HeadCam.global_transform.basis.y * 0.2)

func setdoppelganger(doppelgangeron):
	if doppelgangeron:
		if doppelganger == null:
			doppelganger = load("res://nodescenes/PlayerPuppet.tscn").instance()
			doppelganger.set_name("Doppelganger")
			get_parent().add_child(doppelganger)
			doppelganger.initplayerpuppet(ovr_hand_tracking != null)
		doppelganger.visible = true
		doppelganger.global_transform.origin = $HeadCam.global_transform.origin - 3*Vector3($HeadCam.global_transform.basis.z.x, 0, $HeadCam.global_transform.basis.z.z).normalized()
		
	elif not doppelgangeron and doppelganger != null:
		doppelganger.queue_free()
		doppelganger = null	

func _ready():
	pass

func _physics_process(_delta):
	pass

remote func setavatarposition(positiondict):
	print("ppt nope not master ", positiondict)

puppet func bouncedoppelgangerposition(bouncebackID, positiondict):
	rpc_unreliable_id(bouncebackID, "setdoppelgangerposition", positiondict)

func swapcontrollers():
	var cidl = $HandLeftController.controller_id
	var cidr = $HandRightController.controller_id
	$HandLeftController.controller_id = cidr
	$HandRightController.controller_id = cidl
	$HandLeft.controller_id = cidr
	$HandRight.controller_id = cidl

remotesync func playvoicerecording(wavrecording):
	print("playing recording ", wavrecording.size()) 
	var stream = AudioStreamSample.new()
	stream.format = AudioStreamSample.FORMAT_16_BITS
	stream.data = wavrecording
	stream.mix_rate = 44100
	stream.stereo = true
	$HandRight/AudioStreamPlayer3D.stream = stream
	$HandRight/AudioStreamPlayer3D.play()


func playerpositiondict():
	var t0 = OS.get_ticks_msec()*0.001
	return { "timestamp":t0, 
			 "playertransform":global_transform, 
			 "headcamtransform":$HeadCam.transform, 
			 "handleft": $HandLeft.handpositiondict(t0), 
			 "handright": $HandRight.handpositiondict(t0), 
			 "laserpointer": { "orient":$HandRight.pointerposearvrorigin, 
							   "length": LaserOrient.get_node("Length").scale.z, 
							   "spotvisible": LaserOrient.get_node("LaserSpot").visible }
			}

func _process(delta):
	if Tglobal.questhandtracking:
		$HandLeft.process_ovrhandtracking(delta)
		$HandRight.process_ovrhandtracking(delta)
	elif Tglobal.VRoperating:
		$HandLeft.process_normalvrtracking(delta)
		$HandRight.process_normalvrtracking(delta)
	else:
		var hx = 0
		if Input.is_action_pressed("lh_shift"):
			var lhkeyvec = Vector2(0, 0)
			if Input.is_action_pressed("lh_forward"):   lhkeyvec.y += 1
			if Input.is_action_pressed("lh_backward"):  lhkeyvec.y += -1
			if Input.is_action_pressed("lh_left"):      lhkeyvec.x += -1
			if Input.is_action_pressed("lh_right"):     lhkeyvec.x += 1
			hx = lhkeyvec.x
			lhkeyvec.x = 0
			var vtarget = -$HeadCam.global_transform.basis.z*20 + $HeadCam.global_transform.basis.x*lhkeyvec.x*15*delta + Vector3(0, lhkeyvec.y, 0)*15*delta
			$HeadCam.look_at($HeadCam.global_transform.origin + vtarget, Vector3(0,1,0))
			rotation_degrees.y += $HeadCam.rotation_degrees.y
			$HeadCam.rotation_degrees.y = 0
		$HandRight.process_keyboardcontroltracking($HeadCam, Vector2(hx*0.033, 0))
	LaserOrient.global_transform = global_transform*$HandRight.pointerposearvrorigin

func initkeyboardcontroltrackingnow():
	$HandLeft.initkeyboardtracking()
	$HandRight.initkeyboardtracking()

func initnormalvrtrackingnow():
	$HandLeft.initnormalvrtracking($HandLeftController)
	$HandRight.initnormalvrtracking($HandRightController)
	$HandLeft.addremotetransform("middle_null", get_node("/root/Spatial/BodyObjects/MovePointThimble"))

func initquesthandtrackingnow(lovr_hand_tracking):
	Tglobal.questhandtracking = true
	$HeadCam/HeadtorchLight.shadow_enabled = false

	ovr_hand_tracking = lovr_hand_tracking
	$HandLeft.initovrhandtracking(ovr_hand_tracking, $HandLeftController)
	$HandRight.initovrhandtracking(ovr_hand_tracking, $HandRightController)
	$HandLeft.addremotetransform("middle_null", get_node("/root/Spatial/BodyObjects/MovePointThimble"))
	
