extends Spatial

var arvr_openvr = null; 
var arvr_quest = null; 

# Notes: we have used Function_Direct_movement.drag_factor == 0 to disable velocity and gravity

# Stuff to do:
# * Ray to have up arrow so twist option possible
# * Select menu options popup panel using VR_BUTTON_BY 
# * make save and load options then
# * Separate OneTunnel class with all the geometry that drives the sketch system
# * import centreline with LRUDs properly
# * better select and shape colours
# * Fall upward to celing when not on above the cave
# * Special rods connecting centreline nodes to the sketch below
# * active 2 node rods to lock the sketch
# * move sketch up and down
# * each sketch node retains the UV point on the drawing at time it was made
# * Each node finds its normal plane and resolves lines around it
# * nodes have push-pull or cross-section plane
# * Line sections and triangle areas can be split
# * floor and wall textures
# * Boulders and gravel and particles

var perform_runtime_config = true
var ovr_init_config = null
var ovr_performance = null

func _ready():
	print("Initializing VR");
	print("  Available Interfaces are %s: " % str(ARVRServer.get_interfaces()));
	arvr_openvr = ARVRServer.find_interface("OpenVR")
	arvr_quest = null # ARVRServer.find_interface("OVRMobile");

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
			var viewport = get_viewport()
			viewport.arvr = true
			print("tttt", viewport.hdr, " ", viewport.keep_3d_linear)
			#viewport.hdr = false
			viewport.keep_3d_linear = true
			Engine.target_fps = 90
			OS.vsync_enabled = false;
			print("  Success initializing OpenVR Interface.");

	else:
		print("*** VR not working")
	
	# pass across object pointers to the pointer system
	var pointer = $ARVROrigin/ARVRController_Right/pointersystem
	pointer.sketchsystem = $SketchSystem
	pointer.drawnfloor = $drawnfloor
	pointer.guipanel3d = $GUIPanel3D
	pointer.guipanel3d.visible = false

func _process(_delta):
	if !perform_runtime_config:
		ovr_performance.set_clock_levels(1, 1)
		ovr_performance.set_extra_latency_mode(1)
		perform_runtime_config = true


