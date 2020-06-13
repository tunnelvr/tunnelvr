extends Spatial

var arvr_openvr = null; 
var arvr_quest = null; 


# Stuff to do:
# * plot the direction of the bits after the spike
# * label polys not to fill if there is a two sided edge
# * abolish nodeuvs and others from OnePathNode object and ref directly
# * Fall upward to ceiling when not on above the cave
# * move textpanel out to top level with the GUI stuff
# * anchor nodes capable of pulling plane up and down
# * floor and wall textures programmable
# * Each node finds its normal plane and resolves lines around it
# * nodes have push-pull or cross-section plane
# * Line sections and triangle areas can be split
# * Boulders and gravel and particles
# * set the floor shape size according to aspect ratio read from the bitmap 1.285239=(3091/2405.0)
# * Report bug that disable depth check puts transparent objects in front
# * Report bug check ray intersect plane is in the plane and report if not!

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
	pointer.drawingwall = $drawingwall
	pointer.guipanel3d = $GUIPanel3D
	pointer.guipanel3d.visible = false
	$SketchSystem/Centreline.drawnfloor = $drawnfloor
	$ARVROrigin/ARVRController_Right/pointersystem/LaserSpot.visible = false
	
func _process(_delta):
	if !perform_runtime_config:
		ovr_performance.set_clock_levels(1, 1)
		ovr_performance.set_extra_latency_mode(1)
		perform_runtime_config = true


