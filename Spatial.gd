extends Spatial

var arvr_openvr = null; 
var arvr_quest = null; 


# Stuff to do:
# * tap right and up to grow XC drawing
# * draw connecting lines between nodes on xcdrawing and other edits (the pathlines)
# * save and load the xcdrawings to the file as pools of vectors
# * XCnodes to receive the modes in the same wall
# * node on XC plane to have reflection on the floor to match the sketch that's there
# * replace the drawingwall with the XCdrawings (with a NodeOrientPreview in it?)
# * We trace a network of nodes on the floor how we like
# * Is the ground drawing actually just a 2D drawing which the cross sections will be guided by?
# * Primary construction of cross-section contours around centreline nodes
# * Nodes have floor/wall/ceiling type or-ed so that when edges and faces get anded by their point members their category is set
# * Colour floor/wall/ceiling faces accordingly
# * Interpolate cross sections that are joined along the plan2D contour and slinky tubes not straight pipes
# * This means we have driving edges that run the interpolation over what gets interpolated
# * Requires an undo of each of these settings
# * capability of selecting faces and splitting with points
# * abolish nodeuvs and others from OnePathNode object and ref directly
# * Report bug that disable depth check puts transparent objects in front
# * node flags of floor, wall, ceiling types so that edges and triangles inherit from this 
# * nodeinwardvecs basis calculation to be moved
# * Fall upward to ceiling when not on above the cave
# * move textpanel out to top level with the GUI stuff
# * triangulations to better reflect the normals given at the nodes
# * floor and wall textures programmable
# * shadow from the pulled body and head-torch required
# * nodes have push-pull or cross-section plane
# * Line sections and triangle areas can be split
# * Boulders and gravel and particles
# * set the floor shape size according to aspect ratio read from the bitmap 1.285239=(3091/2405.0)
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
	pointer.nodeorientationpreview = $SketchSystem/NodeOrientationPreview
	pointer.guipanel3d = $GUIPanel3D
	pointer.guipanel3d.visible = false
	
	$SketchSystem/Centreline.drawnfloor = $drawnfloor
	$ARVROrigin/ARVRController_Right/pointersystem/LaserSpot.visible = false
	$GUIPanel3D.sketchsystem = $SketchSystem
	
func _process(_delta):
	if !perform_runtime_config:
		ovr_performance.set_clock_levels(1, 1)
		ovr_performance.set_extra_latency_mode(1)
		perform_runtime_config = true


