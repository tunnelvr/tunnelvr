extends Spatial

var arvr_openvr = null; 
var arvr_quest = null; 

# Notes: we have used Function_Direct_movement.drag_factor == 0 to disable velocity and gravity

# Stuff to do:
# * OnePathNode to record floorname.png and UV position 
#    var drawingname = ""
#    var uvpoint = null   # Vector2 of in the material
# * use the drawingname and UV point to set the texture in the triangles

# * anchor node type (like normal node) which can be drawn and moved
#      and is connected to the centreline with another strip and gets UV of drawing
# * two activated anchor nodes slide everything around relative to them
# * Fall upward to ceiling when not on above the cave
# * anchor nodes capable of pulling plane up and down
# * Separate OneTunnel class with all the geometry that drives the sketch system
# * each sketch node retains the UV point on the drawing at time it was made
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
	pointer.drawnfloor = $drawnfloor
	pointer.guipanel3d = $GUIPanel3D
	pointer.guipanel3d.visible = false

func _process(_delta):
	if !perform_runtime_config:
		ovr_performance.set_clock_levels(1, 1)
		ovr_performance.set_extra_latency_mode(1)
		perform_runtime_config = true


