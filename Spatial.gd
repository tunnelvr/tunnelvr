extends Spatial

var arvr_openvr = null; 
var arvr_quest = null; 

# Notes: we have used Function_Direct_movement.drag_factor == 0 to disable velocity and gravity

# Stuff to do:
# * Prerecord a set of nodes
# * Load in those nodes
# * Do the assemble into polygons 
# * Select menu options popup panel using VR_BUTTON_BY
# * Use immediate_code to run tests on gdscript
# * Would be good if triangle_mesh intersect gave which triangle was intersected

var perform_runtime_config = true
var ovr_init_config = null
var ovr_performance = null

func _ready():
	print("Initializing VR");
	print("  Available Interfaces are %s: " % str(ARVRServer.get_interfaces()));
	arvr_openvr = ARVRServer.find_interface("OpenVR")
	arvr_quest = ARVRServer.find_interface("OVRMobile");

	if arvr_quest:
		print("found quest, initializing")
		ovr_init_config = preload("res://addons/godot_ovrmobile/OvrInitConfig.gdns").new()
		ovr_performance = preload("res://addons/godot_ovrmobile/OvrPerformance.gdns").new()
		perform_runtime_config = false
		ovr_init_config.set_render_target_size_multiplier(1)
		if arvr_quest.initialize():
			get_viewport().arvr = true;
			Engine.target_fps = 72;
			print("  Success initializing Quest Interface.");
	
	elif arvr_openvr:
		print("found openvr, initializing")
		if arvr_openvr.initialize():
			get_viewport().arvr = true
			print("tttt", get_viewport().keep_3d_linear)
			get_viewport().keep_3d_linear = true
			Engine.target_fps = 90
			OS.vsync_enabled = false;
			print("  Success initializing OpenVR Interface.");

	else:
		print("*** VR not working")
	
	# pass across object pointers to the pointer system
	var pointer = $ARVROrigin/ARVRController_Right/pointersystem
	pointer.sketchsystem = $SketchSystem
	pointer.drawnfloor = $drawnfloor
	#print("moved", on, from, to)

func _process(_delta):
	if !perform_runtime_config:
		ovr_performance.set_clock_levels(1, 1)
		ovr_performance.set_extra_latency_mode(1)
		perform_runtime_config = true


