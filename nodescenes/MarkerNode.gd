extends RigidBody

func _ready():
	pass
	
func jump_up():
	set_axis_velocity(Vector3(0,10,0))
