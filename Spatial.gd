extends Spatial


# Stuff to do:

# * papertype should not be environment collision (just pointer collisions)

# * duplicate floor trimming out and place at different Z-levels

# * darken frame overlay on the area to get the borders better

# * Transmit create xcdrawing across to client

# * doppelganger and avatar should have laser cursor

# * all XCdrawing repositions should communicate.  
# * also communicate node positions and updates (just as a batch on redraw) 
# * formalize the exact order of updates of positions of things so we don't get race conditions
# * Connecting to server should simply cause an rpc of the json saved file to save and load
# * transmit rpc_reliable when trigger released

# * pointertargettypes should be an enum for itself
# * LaserRayCast.collision_mask should use an enum



# * moving floor up and down (also transmitted)
# *  XCpositions and new ones going through rsync?  

# * regexp option button to download all the files into the user directory.  

# * VR leads@skydeas1  and @brainonsilicon in Leeds (can do a trip there)

# * keyboard controls to do mouse buttons (and point and click when not captured)
# * point and click under the mouse cursor when not captured! should be a laser beam out of the camera!
#var dropPlane  = Plane(Vector3(0, 0, 1), z)
#var position3D = dropPlane.intersects_ray(camera.project_ray_origin(position2D),
#                             			  camera.project_ray_normal(position2D))
# * show this on the remote computer (the status of the laser)

# * copy in more drawings as bits of paper size that can be picked up and looked at
# * think on how to remap the controls somehow.  Maybe some twist menus
# * add more keyboard controls
# * some XCtypes are little bits of paper we have made, before they become full floors that can be moved by hand before they are expanded
# * keyboard control of mouseclicks (when not in mouse capture mode) to do the laser (or remove laser entirely for the clicking on windows)

# * CSG avatar head to have headtorch light that goes on or off and doesn't hit ceiling (gets moved down)

# * bring in a tiny version of the floor drawing as a holdable object
# * use cursor as tractor beam for those and the pick up and reorient

# * shiftfloorfromdrawnstations in shiftxcdrawingposition
# * hexagonal crosssections	for xsectgp in xsectgps:
#		var xsectindexes = xsectgp.xsectindexes
#		var xsectrightvecs = xsectgp.xsectrightvecs
#		var xsectlruds = xsectgp.xsectlruds

# * delete a tube that has no connections on it
# * Movement connection between floortype and centreline
# * cache value of sketchsystem.get_node("XCdrawings").get_node(xctube.xcname1).drawingtype
# * removexcnode should actually cause a redraw (but not a move)
# * ^^ should move redraws out of the system
# * systematically do the updatetubelinkpaths and updatetubelinkpaths recursion properly 

# * Alter the OnePathNode system to make centreline nodes (with different meshes)

# * include a list of URLs for the drawings and bring them in as small bits of xccrossing bits of paper
# *  option in the GUIpanel

# * Bring in XCdrawings that are hooked to the centreline that will highlight when they get it
# * these cross sections are tied to the centrelinenodes and not the floor, and are prepopulated with the cross sections dimensions and tubes
# * Load and move the floor on load

# * holding and moving and trimming small texture xcdrawings like puzzling places
# * remove all previous centreline code
# * ability to duplicate the floor with windows in it and move it up close to the centrelines
# * mapping texture types in the zones of the cross sections (cross sections should be hexes) 

# * experiment with junctions cross sections
# * finally kinked xcs

# * systems into own file

# * use chinhotspot to use as microphone (on grip) and then button to playback

# * compress and decompress the audio stream (LZstream) and make a godot proposal
# * do advanced functions like slicetubetoxcdrawing only on the nodepoints array (though still need to implement plane flattening)

# * Laser change colour when pointing onto something (according to what it points onto)
# * pointer target and selected target from pointersystem into sketchsystem
# * import other floor XCs for drawing on and snipping out, putting into places.
# * ability to adjust angle and brightness of headtorch in same way with raycast stub

# * change colour of head and hands of each avatar

# * avoid calling network peer when not connected to anything
# * start the sending over of positions from the server as updates happen
# * laser/spot/laser shadow/laser-selectline all more global (shared selection, or not)
# * begin with mapfinding system from downloaded png files that are snipped up and placed in relation to a cave model
# *  lay out the bits of paper on a board and lets you put them on the survey
# *  online copies of the survey scans

# * simplify the double points we get in the slices (take the mid-point of them) or detect the coplanar points from coplanar corresponding input edges)
# * clear up the laser pointer logic and materials
# * automatically make the xcplane big enough as you draw close to its edge
# * shift pick connection to delete nodes up to next junction
# * scan through other drawings on back of hand
# * check stationdrawnnode moves the ground up
# * Need to ask to improve the documentation on https://docs.godotengine.org/en/latest/classes/class_meshinstance.html#class-meshinstance-method-set-surface-material
# *   See also https://godotengine.org/qa/3488/how-to-generate-a-mesh-with-multiple-materials
# *   And explain how meshes can have their own materials, that are copied into material/0, and the material reappears if material/0 set to null
# * CSG mesh with multiple materials group should have material0, material1 etc
# * Report bug check ray intersect plane is in the plane and report if not!

# * and loading (remembering the transforms) so it starts exactly where it left off
# * redo shiftfloorfromdrawnstations with nodes in the area of some kind (decide what to do about the scale)
# * grip click to hide a tube segment (how to bring back?)
# * xcdrawingplane background thing be scaled when copied
# * xcdrawingplane background thing change colour on grip and hide
# * think about the height plane
# * third (middle) connection point on xcdrawing bends it into 2 planes

# * Colour floor/wall/ceiling faces accordingly
# * Requires an undo of each of these settings
# * capability of selecting faces and splitting with points
# * Report bug that disable depth check puts transparent objects in front
# * node flags of floor, wall, ceiling types so that edges and triangles inherit from this 
# * floor and wall textures programmable
# * Boulders and gravel and particles

var arvr_openvr = null; 
var arvr_quest = null; 

export var hostipnumber: String = ""
export var hostportnumber: int = 8002

var perform_runtime_config = true
var ovr_init_config = null
var ovr_performance = null
var networkID = 0

onready var playerMe = $Players/PlayerMe

	
func _ready():
	
	if hostipnumber == "":
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
			playerMe.arvrinterface = arvr_openvr

	else:
		print("*** VR not working")

	var networkedmultiplayerenet = NetworkedMultiplayerENet.new()
	get_tree().connect("network_peer_connected", self, "_player_connected")
	get_tree().connect("network_peer_disconnected", self, "_player_disconnected")
	if hostipnumber == "":
		networkedmultiplayerenet.create_server(hostportnumber, 5)
		playerMe.connectiontoserveractive = true
	else:
		networkedmultiplayerenet.create_client(hostipnumber, hostportnumber)
		get_tree().connect("connected_to_server", self, "_connected_to_server")
		get_tree().connect("connection_failed", self, "_connection_failed")
		get_tree().connect("server_disconnected", self, "_server_disconnected")
		playerMe.connectiontoserveractive = false
		playerMe.rotate_y(180)
		playerMe.global_transform.origin += 3*Vector3(playerMe.get_node("HeadCam").global_transform.basis.z.x, 0, playerMe.get_node("HeadCam").global_transform.basis.z.z).normalized()
	get_tree().set_network_peer(networkedmultiplayerenet)
	networkID = get_tree().get_network_unique_id()
	print("nnet-id ", networkID)
	rpc("ding", 999, networkID)
	playerMe.set_network_master(networkID)
	
# May need to use Windows Defender Firewall -> Inboard rules -> New Rule and ports
# Also there's another setting change to allow pings
func _player_connected(id):
	print("_player_connected ", id)
	playerMe.set_name("NetworkedPlayer"+String(networkID))
	var playerothername = "NetworkedPlayer"+String(id)
	if not $Players.has_node(playerothername):
		var playerOther = preload("res://nodescenes/PlayerPuppet.tscn").instance()
		playerOther.set_network_master(id)
		playerOther.set_name(playerothername)
		$Players.add_child(playerOther)
	
func _player_disconnected(id):
	print("_player_disconnected ", id)
	var playerothername = "NetworkedPlayer"+String(id)
	if $Players.has_node(playerothername):
		$Players.get_node(playerothername).queue_free()
		
func _connected_to_server():
	print("_connected_to_server")
	playerMe.connectiontoserveractive = true
func _connection_failed():
	print("_connection_failed")
func _server_disconnected():
	print("_server_disconnected")
	playerMe.connectiontoserveractive = false
	
remotesync func ding(t, dd):
	print("ding ding ding ", t)	
	print("currentpath ", get_path())

func _process(_delta):
	if !perform_runtime_config:
		ovr_performance.set_clock_levels(1, 1)
		ovr_performance.set_extra_latency_mode(1)
		perform_runtime_config = true


