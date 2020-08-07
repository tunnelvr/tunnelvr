extends ARVROrigin

var xcdrawing_material = preload("res://guimaterials/XCdrawing.material")
var xcdrawing_active_material = preload("res://guimaterials/XCdrawing_active.material")
onready var xcdrawing_material_albedoa = xcdrawing_material.albedo_color.a
onready var xcdrawing_active_material_albedoa = xcdrawing_active_material.albedo_color.a
onready var doppelganger = get_node("../Players/Doppelganger")
	
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
	print("dddd ", doppelganger, get_node(".."))

func _process(_delta):
	if is_inside_tree() and is_instance_valid(doppelganger):
#		doppelganger.get_node("HeadCam").global_transform = Transform($ARVRCamera.global_transform.basis, $ARVRCamera.global_transform.origin + vdisp)
#		doppelganger.get_node("HandLeft").global_transform = Transform($ARVRController_Left.global_transform.basis, $ARVRController_Left.global_transform.origin + vdisp)
#		doppelganger.get_node("HandRight").global_transform = Transform($ARVRController_Right.global_transform.basis, $ARVRController_Right.global_transform.origin + vdisp)
		doppelganger.global_transform.origin.y = global_transform.origin.y
		doppelganger.global_transform.basis = global_transform.basis
		doppelganger.get_node("HeadCam").transform = Transform($ARVRCamera.transform.basis, $ARVRCamera.transform.origin)
		doppelganger.get_node("HandLeft").transform = Transform($ARVRController_Left.transform.basis, $ARVRController_Left.transform.origin)
		doppelganger.get_node("HandRight").transform = Transform($ARVRController_Right.transform.basis, $ARVRController_Right.transform.origin)
