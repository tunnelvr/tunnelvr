extends Spatial

var arvr_openvr = null; 
var arvr_quest = null; 

# Stuff to do:

# * move GUIPanel3D to ARVROrigin
# * Rename ARVR stuff to headcam handleft eft
# * Move the Laser into the CSGMesh_righthand
# * laser/spot/laser shadow/laser-selectline all more global (shared selection, or not)
# * boulder clutter to HandRight/pointersystem
# * HeadCam.environment moved somewhere more global

# * XCdrawing texture to scale as meters with scale and offsets sorted out to be on the origin
# * simplify the double points we get in the slices (take the mid-point of them)
# * make a doppleganger of the ARVR origin and controller and hands, for use with the networking
# * clear up the laser pointer logic and materials
# * shorten laser pointer to end on the node
# * automatically make the xcplane big enough as you draw close to its edge
# * shift pick connection to delete nodes up to next junction
# * option to start recording of the person to a file, and then stop recording, then replay recording -- in anticipation of multiplayer
# * xcdrawing plane texture should be a 1m checkerboard as a shader repeating
# * capsule tall enough to contain the headtorch
# * scan through other drawings on back of hand
# * check stationdrawnnode moves the ground up
# * Need to ask to improve the documentation on https://docs.godotengine.org/en/latest/classes/class_meshinstance.html#class-meshinstance-method-set-surface-material
# *   See also https://godotengine.org/qa/3488/how-to-generate-a-mesh-with-multiple-materials
# *   And explain how meshes can have their own materials, that are copied into material/0, and the material reappears if material/0 set to null
# *  because distortions don't ruin the topology of the area and do a whole set at once, and lend self to subdividing edges if curvature too great
# * should the XCdrawing be flat and lifted up for XC, rather than tipped back for floordrawing
# * and loading (remembering the transforms) so it starts exactly where it left off
# * change "OnePathNodes" to "floordrawingnode"
# * the headtorch should have ability to rotate down or up
# * redo shiftfloorfromdrawnstations with nodes in the area of some kind (decide what to do about the scale)
# * make tubes automatically update on moves of nodes.  
# * tie centreline nodes to the drawn floor same way other movements are?
# * grip click to hide a tube segment (how to bring back?)
# * cycle through textures on a tube section (as well as hiding)
# * xcdrawingplane background thing be scaled when copied
# * xcdrawingplane background thing change colour on grip and hide
# * think about the height plane
# * drag and shift all nodes up or expand in an xcdrawing (part of group node moving with circular paint brushing pushing)
# * Normal drawing to be XCdrawing, but horizontal and with a connections between XCdrawings
# * third (middle) connection point on xcdrawing bends it into 2 planes
# * select cursor should be present when connecting to other nodes, even when point node is hidden
# * auto update the shells on path join or node moved
# * auto shift drawing on load and station nodes exist
# * abolish the set_materialoverride use and remove those 3 line scripts
# * experiment with making an offset of the XC and a tube
# * how to duplicate, move and shift an XCdrawing with gestures
# * remove poolintarrays because of all by value
# * interpolate the XC as we drag along the runs traced in the floor
# * show cursor and XC plane in front of the shell if we want to 
# * update shells incrementally per tube, not whole thing at once
# * try some rock texture onto the shells (esp the ceilings)
# * allocate junctions and curved XCs (or with a split panel at 0 and different angle)
# * shell code should have rocky texture on ceilings

# * tap right and up to grow XC drawing
# * XC to record its UV and X-vector position on the sketch maybe
# * Nodes have floor/wall/ceiling type or-ed so that when edges and faces get anded by their point members their category is set
# * Colour floor/wall/ceiling faces accordingly
# * Interpolate cross sections that are joined along the plan2D contour and slinky tubes not straight pipes
# * This means we have driving edges that run the interpolation over what gets interpolated
# * Requires an undo of each of these settings
# * capability of selecting faces and splitting with points
# * Report bug that disable depth check puts transparent objects in front
# * node flags of floor, wall, ceiling types so that edges and triangles inherit from this 
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
			$Players/PlayerVR.arvrinterface = arvr_openvr

	else:
		print("*** VR not working")

	return 
	
	get_tree().connect("network_peer_connected", self, "_player_connected")
	get_tree().connect("network_peer_disconnected", self, "_player_disconnected")
	var host = NetworkedMultiplayerENet.new()
	host.create_server(10567, 5)
	#host.create_client("127.0.0.1", 10567)
	get_tree().set_network_peer(host)
	print("nnet-id ", get_tree().get_network_unique_id())
	rpc("ding", 999)
	print("ding called")
	
	#var client = NetworkedMultiplayerENet.new()
	#client.create_client("127.0.0.1", 9009)
	#get_tree().set_network_peer(client)
	#print("nnet-id ", get_tree().get_network_unique_id())
	#rpc("ding", 9991)
	#print("ding called again")

func _player_connected(id):
	print("_player_connected ", id)
	
func _player_disconnected(id):
	print("_player_disconnected ", id)
	
remotesync func ding(t):
	print("ding ding ding ", t)	
	print("currentpath ", get_path())
	

func _process(_delta):
	if !perform_runtime_config:
		ovr_performance.set_clock_levels(1, 1)
		ovr_performance.set_extra_latency_mode(1)
		perform_runtime_config = true


