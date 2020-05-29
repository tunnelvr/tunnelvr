extends Spatial

var arvr_open_vr_interface = null; 

# Notes: we have used Function_Direct_movement.drag_factor == 0 to disable velocity and gravity

func _ready():
	print("Initializing VR");
	arvr_open_vr_interface = ARVRServer.find_interface("OpenVR")
	if arvr_open_vr_interface:
		if arvr_open_vr_interface.initialize():
			get_viewport().arvr = true
			print("tttt", get_viewport().keep_3d_linear)
			get_viewport().keep_3d_linear = true
			Engine.target_fps = 90
			OS.vsync_enabled = false;
			print("  Success initializing OpenVR Interface.");
	
	# pass across object pointers to the pointer system
	var pointer = $ARVROrigin/ARVRController_Right/Function_pointer
	pointer.sketchsystem = $SketchSystem
	pointer.drawnfloor = $drawnfloor

	#print("moved", on, from, to)


