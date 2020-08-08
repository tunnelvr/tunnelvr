extends ARVROrigin

var xcdrawing_material = preload("res://guimaterials/XCdrawing.material")
var xcdrawing_active_material = preload("res://guimaterials/XCdrawing_active.material")
onready var xcdrawing_material_albedoa = xcdrawing_material.albedo_color.a
onready var xcdrawing_active_material_albedoa = xcdrawing_active_material.albedo_color.a
onready var doppelganger = null # get_node("../Doppelganger")
var arvrinterface = null

func setheadtorchlight(torchon):
	$HeadCam/HeadtorchLight.visible = torchon
	get_node("/root/Spatial/WorldEnvironment").environment = preload("res://vr_underground.tres") if torchon else preload("res://default_env.tres")
	get_node("/root/Spatial/WorldEnvironment/DirectionalLight").visible = not torchon
	# translucent walls reflect too much when torchlight is on
	xcdrawing_material.albedo_color.a = 0.1 if torchon else xcdrawing_material_albedoa
	xcdrawing_active_material.albedo_color.a = 0.1 if torchon else xcdrawing_active_material_albedoa

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
	print("dddd ", doppelganger, get_node(".."))

func _physics_process(_delta):
	pass

remote func setavatarposition(playertransform, headcamtransform, handlefttransform, handrighttransform):
	print("ppt_nope ", playertransform.origin.x, " ", headcamtransform.origin.x)
	#global_transform = playertransform
	#$HeadCam.transform = headcamtransform
	#$HandLeft.transform = handlefttransform
	#$HandRight.transform = handrighttransform
