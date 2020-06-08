extends StaticBody

var stationname = "unknown"

func _ready():
	pass

func getnodetype():
	return "ntStation"

func set_materialoverride(material, bselected_type):
	$CollisionShape/MeshInstance.material_override = material
	if bselected_type:
		var textpanel = get_node("../../TextPanel")
		print("ttttextpanel ", textpanel)
		if material != null:
			textpanel.get_node("Viewport/Label").text = stationname
			textpanel.global_transform.origin = global_transform.origin + Vector3(0, 0.3, 0)
			textpanel.visible = true
			
		else:
			textpanel.visible = false
	
