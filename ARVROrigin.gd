extends ARVROrigin

var xcdrawing_material = preload("res://guimaterials/XCdrawing.material")
var xcdrawing_active_material = preload("res://guimaterials/XCdrawing_active.material")
onready var xcdrawing_material_albedoa = xcdrawing_material.albedo_color.a
onready var xcdrawing_active_material_albedoa = xcdrawing_active_material.albedo_color.a
var doppelganger = null 

var arvrinterface = null
var connectiontoserveractive = false
var networkID = 0
var bouncetestnetworkID = 0

func setheadtorchlight(torchon):
	$HeadCam/HeadtorchLight.visible = torchon
	get_node("/root/Spatial/WorldEnvironment").environment = preload("res://vr_underground.tres") if torchon else preload("res://default_env.tres")
	get_node("/root/Spatial/WorldEnvironment/DirectionalLight").visible = not torchon
	# translucent walls reflect too much when torchlight is on
	xcdrawing_material.albedo_color.a = 0.1 if torchon else xcdrawing_material_albedoa
	xcdrawing_active_material.albedo_color.a = 0.1 if torchon else xcdrawing_active_material_albedoa
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
