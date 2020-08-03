extends Spatial


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

const MarkerNode = preload("res://nodescenes/MarkerNode.tscn")

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func _input(event):
	if Input.is_key_pressed(KEY_B):
		print("making new boulder")
		var righthand = get_node("../ARVROrigin/ARVRController_Right")
		var markernode = MarkerNode.instance()
		var nc = get_child_count()
		markernode.get_node("CollisionShape").scale = Vector3(0.4, 0.6, 0.4) if ((nc%2) == 0) else Vector3(0.2, 0.4, 0.2)
		markernode.global_transform.origin = righthand.global_transform.origin - 0.9*righthand.global_transform.basis.z
		markernode.linear_velocity = -5.1*righthand.global_transform.basis.z
		add_child(markernode)