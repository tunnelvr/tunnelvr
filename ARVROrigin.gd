extends ARVROrigin

var xcdrawing_material = preload("res://guimaterials/XCdrawing.material")
var xcdrawing_active_material = preload("res://guimaterials/XCdrawing_active.material")
onready var xcdrawing_material_albedoa = xcdrawing_material.albedo_color.a
onready var xcdrawing_active_material_albedoa = xcdrawing_active_material.albedo_color.a
	
func settorchlight(torchon):
	$ARVRCamera/HeadtorchLight.visible = torchon
	$DirectionalLight.visible = not torchon
	$ARVRCamera.environment = preload("res://vr_underground.tres") if torchon else null
	# translucent walls reflect too much when torchlight is on
	xcdrawing_material.albedo_color.a = 0.1 if torchon else xcdrawing_material_albedoa
	xcdrawing_active_material.albedo_color.a = 0.1 if torchon else xcdrawing_active_material_albedoa

func _ready():
	#settorchlight(false)
	pass
