extends ARVROrigin

var doppelganger = null 

var networkID = 0
var bouncetestnetworkID = 0

func setheadtorchlight(torchon):
	$HeadCam/HeadtorchLight.visible = torchon
	get_node("/root/Spatial/WorldEnvironment").environment = preload("res://environments/underground_env.tres") if torchon else preload("res://environments/default_env.tres")
	get_node("/root/Spatial/WorldEnvironment/DirectionalLight").visible = not torchon
	get_node("/root/Spatial/MaterialSystem").adjustmaterialtotorchlight(torchon)
	get_node("/root/Spatial/SoundSystem").quicksound("ClickSound", $HeadCam.global_transform.origin + $HeadCam.global_transform.basis.y * 0.2)

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
	pass

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
	$HandRight/AudioStreamPlayer3D.stream = stream
	$HandRight/AudioStreamPlayer3D.play()

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

func _process(delta):
	if ovr_hand_tracking != null:
		#process_handtracking(delta)
		$HandLeftH.process_ovrhandtracking(delta)
		$HandRightH.process_ovrhandtracking(delta)

	if Tglobal.VRstatus == "none" and Input.is_action_pressed("lh_shift"):
		var lhkeyvec = Vector2(0, 0)
		if Input.is_action_pressed("lh_forward"):   lhkeyvec.y += 1
		if Input.is_action_pressed("lh_backward"):  lhkeyvec.y += -1
		if Input.is_action_pressed("lh_left"):      lhkeyvec.x += -1
		if Input.is_action_pressed("lh_right"):     lhkeyvec.x += 1
		var vtarget = -$HeadCam.global_transform.basis.z*20 + $HeadCam.global_transform.basis.x*lhkeyvec.x*15*delta + Vector3(0, lhkeyvec.y, 0)*15*delta
		$HeadCam.look_at($HeadCam.global_transform.origin + vtarget, Vector3(0,1,0))
		rotation_degrees.y += $HeadCam.rotation_degrees.y
		$HeadCam.rotation_degrees.y = 0


var ovr_hand_tracking = null

func initnormalvrtrackingnow():
	$HandLeftH.initnormalvrtracking($HandLeft)
	$HandRightH.initnormalvrtracking($HandRight)

func initquesthandtrackingnow(lovr_hand_tracking):
	Tglobal.questhandtracking = true
	$HeadCam/HeadtorchLight.shadow_enabled = false

	ovr_hand_tracking = lovr_hand_tracking
	$HandLeftH.initovrhandtracking(ovr_hand_tracking, $HandLeft)
	$HandRightH.initovrhandtracking(ovr_hand_tracking, $HandRight)
	
	$HandLeft.addremotetransform("middle_null", get_node("/root/Spatial/BodyObjects/MovePointThimble"))
	
