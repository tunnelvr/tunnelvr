extends Spatial

var arvr_openvr = null; 
var arvr_quest = null; 


# Stuff to do:
# * selected drawn station node to have line to station with name above it
# * shiftfloorfromdrawnstations last two touched drawn station nodes activated button slide everything around relative to them
#      and is connected to the centreline with another strip and gets UV of drawing
# * save and load drawn station nodes
# * set the floor shape size according to aspect ratio of the bitmap 1.285239=(3091/2405.0)
# * all other drawnstationnodes need moving same time
# * nodes should be located at their top position and scaled in y to go downwards
# * check ray intersect plane is in the plane and report if not!
# * Fall upward to ceiling when not on above the cave
# * anchor nodes capable of pulling plane up and down
# * Separate OneTunnel class with all the geometry that drives the sketch system
#      and makes a much more efficient update system than doing all at once
# * Each node finds its normal plane and resolves lines around it
# * nodes have push-pull or cross-section plane
# * Line sections and triangle areas can be split
# * floor and wall textures programmable
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
		print("found quest, NOT initializing")
		#ovr_init_config = preload("res://addons/godot_ovrmobile/OvrInitConfig.gdns").new()
		#ovr_performance = preload("res://addons/godot_ovrmobile/OvrPerformance.gdns").new()
		#perform_runtime_config = false
		#ovr_init_config.set_render_target_size_multiplier(1)
		#if arvr_quest.initialize():
		#	get_viewport().arvr = true;
		#	Engine.target_fps = 72;
		#	print("  Success initializing Quest Interface.");
	
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
	pointer.centrelinesystem = $SketchSystem/Centreline
	pointer.drawnfloor = $drawnfloor
	pointer.guipanel3d = $GUIPanel3D
	pointer.guipanel3d.visible = false
	$SketchSystem/Centreline.drawnfloor = $drawnfloor
	
func _process(_delta):
	if !perform_runtime_config:
		ovr_performance.set_clock_levels(1, 1)
		ovr_performance.set_extra_latency_mode(1)
		perform_runtime_config = true


