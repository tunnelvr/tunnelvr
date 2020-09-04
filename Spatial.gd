extends Spatial

# Stuff to do:


# * should give the other player a position near to me:  $SketchSystem.rpc_id(id, "sketchsystemfromdict", $SketchSystem.sketchsystemtodict())
		
# * xctubesconn) == 0 should be a count of the tube types excluding connections to floor
# * DelXC would delete XC and join between the tubes
# * Ghost a wall (or unghost) so we can see through it
# * Cut hole in wall is a different thing -- a proper type and recalculation

# * copy tubeshellsvisible down to the GUID on startup of GUID

# * How is it going to work from planview?
# * a gripclick inserts a new XC in the tube that we can orient and move before applying the slice
#   -- this can be done from the plan view too, 
#   -- plot with front-culling so as to see inside the shapes, and plot with image textures on

# * save and load puts saves my standing position

# * process engine loading of file.  

# * XC in mode where it cannot take new nodes, only as continuation
# * and automatically deletes connective bits -- and reconnects tubes

# * tube has easy clicky ways to add in connecting lines between them (advancing the selected node after starting at a join)

# * confusion between papersheet and floordrawing being XCtype

# * getactivefloordrawing is duff.  we should record floor we are working with relative to an object, by connection

# * deal with positioning papersheet underlay
# * deal with connecting to the papersheet (bigger connectivities needed)
# * deal with seeing the paper drawing when you are inside 
# * active floor papersheet which we used for drawn texture (maybe on the ceiling)

# * check at loading gets the new paper bits in the right place

# * Make a consistent bit of cave in Ireby2

# * A selected tube makes the XCnodes bigger?
# * or we can equivalently cycle through the nodes with right and left VR_Pad

# * papertype should not be environment collision (just pointer collisions)
# * paper to be carried (nailed to same spot on the laser) when we move

# * add networking instructions to README
# * then networking to the Quest(!)  -- this is plausible now

# * remove reliance on rpc sync (a sync call in sketch system) connectiontoserveractive

# * selected XCdrawing would have a handle for moving through the planview
# * enlarged nodes on selected XCdrawing to be visible

# * Quest -- try attaching things to the fingers for steering by relative motions.  
# * Steering by a captain's engine wheel aligned vertical so your left hand can point and move right and touch any part of it
# *  -- you are directing a cursor out there.

# * refraction sphere for accurate pointing -- you hit the sphere and it then goes aligned with your eyes

# * Centrelines and centreline labels off (unless we want them)
# * centreline xcdrawing as extended class?

# * special materials are the sketch image and invisible
# * we can toggle culling to the materials to see inside (means we get everything oriented right) 


# * highlight nodes under pointer system so it's global and simplifies colouring code (active node to be an overlay)

# * XCdrawings only visible when tube is selected (could save a lot of memory)

# * can set the type of the material (including invisible and no collision, so open on side)

# * Position of the avatar other player is queued in its own object by the rpc and only updated on the physics process (and can be delayed and tweened)

# * On the Occulus joystick, a move to the right is equivalent to a click when above 0.9 (but would need to be debounced)

# * grip on XCshape then click gets into rotate mode like with papersheets (but preserving upwardness)

# * possibly lose the connecting xcdrawings to floor feature 
# * just have trimmed sheets that can become floors (or xcs)

# * give it a default cave in position in the resources with default image

# * pointertargettypes should be an enum for itself

# * godot docs.  assert returns null from the function it's in when you ignore it
# * check out HDR example https://godotengine.org/asset-library/asset/110

# * duplicate floor trimming out and place at different Z-levels
#			sketchsystem.rpc("xcdrawingfromdict", xcdrawing.exportxcrpcdata())
# * all XCdrawing repositions should communicate.  
#			sketchsystem.rpc("xcdrawingfromdata", xcdrawing.exportxcrpcdata())
# * formalize the exact order of updates of positions of things so we don't get race conditions
# * transmit rpc_reliable when trigger released on the positioning of a papersheet

# https://developer.oculus.com/learn/hands-design-interactions/
# https://developer.oculus.com/learn/hands-design-ui/
# https://learn.unity.com/tutorial/unit-5-hand-presence-and-interaction?uv=2018.4&courseId=5d955b5dedbc2a319caab9a0#5d96924dedbc2a6236bc1191
# https://www.youtube.com/watch?v=gpQePH-Ffbw

# * moving floor up and down (also transmitted)
# *  XCpositions and new ones going through rsync?  
# * regexp option button to download all the files into the user directory.  
# * VR leads@skydeas1  and @brainonsilicon in Leeds (can do a trip there)

# * copy in more drawings as bits of paper size that can be picked up and looked at
# * think on how to remap the controls somehow.  Maybe some twist menus
# * CSG avatar head to have headtorch light that goes on or off and doesn't hit ceiling (gets moved down)

# * delete a tube that has no connections on it
# * systematically do the updatetubelinkpaths and updatetubelinkpaths recursion properly 

# * Bring in XCdrawings that are hooked to the centreline that will highlight when they get it
# * these cross sections are tied to the centrelinenodes and not the floor, and are prepopulated with the cross sections dimensions and tubes
# * Load and move the floor on load

# * use chinhotspot to use as microphone (on grip) and then button to playback
# * compress and decompress the audio stream (LZstream) and make a godot proposal
# * pointer target and selected target from pointersystem into sketchsystem

# * clear up the laser pointer logic and materials
# * automatically make the xcplane big enough as you draw close to its edge
# * shift pick connection to delete nodes up to next junction
# * scan through other drawings on back of hand
# * check stationdrawnnode moves the ground up

# * Need to ask to improve the documentation on https://docs.godotengine.org/en/latest/classes/class_meshinstance.html#class-meshinstance-method-set-surface-material
# *   See also https://godotengine.org/qa/3488/how-to-generate-a-mesh-with-multiple-materials
# *   And explain how meshes can have their own materials, that are copied into material/0, and the material reappears if material/0 set to null
# * CSG mesh with multiple materials group should have material0, material1 etc

# * and loading (remembering the transforms) so it starts exactly where it left off
# * redo shiftfloorfromdrawnstations with nodes in the area of some kind (decide what to do about the scale)

# * Report bug that disable depth check puts transparent objects in front

var arvr_openvr = null; 
var arvr_quest = null; 
var arvr_oculus = null; 

export var hostipnumber: String = ""
export var hostportnumber: int = 8002

var perform_runtime_config = true
var ovr_init_config = null
var ovr_performance = null
var ovr_hand_tracking = null
var networkID = 0

onready var playerMe = $Players/PlayerMe
var VRstatus = "none"
	
func _ready():
	if hostipnumber == "":
		print("Initializing VR");
		var available_interfaces = ARVRServer.get_interfaces();
		print("  Available Interfaces are %s: " % str(available_interfaces));
		arvr_openvr = ARVRServer.find_interface("OpenVR")
		arvr_quest = ARVRServer.find_interface("OVRMobile")
		arvr_oculus = ARVRServer.find_interface("Oculus")
		
		if arvr_quest:
			print("found quest, initializing")
			ovr_init_config = load("res://addons/godot_ovrmobile/OvrInitConfig.gdns").new()
			ovr_performance = load("res://addons/godot_ovrmobile/OvrPerformance.gdns").new()
			ovr_hand_tracking = load("res://addons/godot_ovrmobile/OvrHandTracking.gdns").new();
			perform_runtime_config = false
			ovr_init_config.set_render_target_size_multiplier(1)
			if arvr_quest.initialize():
				get_viewport().arvr = true;
				Engine.target_fps = 72;
				VRstatus = "quest"
				print("  Success initializing Quest Interface.");

		elif arvr_oculus:
			print("  Found Oculus Interface.");
			if arvr_oculus.initialize():
				get_viewport().arvr = true;
				Engine.target_fps = 80 # TODO: this is headset dependent (RiftS == 80)=> figure out how to get this info at runtime
				OS.vsync_enabled = false;
				VRstatus = "oculus"
				print("  Success initializing Oculus Interface.");

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
				VRstatus = "vive"
				print("  Success initializing OpenVR Interface.");
				playerMe.arvrinterface = arvr_openvr

	if VRstatus == "none":
		print("*** VR not working")
	playerMe.VRstatus = VRstatus
	if VRstatus == "quest":
		playerMe.initquesthandtrackingnow(ovr_hand_tracking)

	var networkedmultiplayerenet = NetworkedMultiplayerENet.new()
	get_tree().connect("network_peer_connected", self, "_player_connected")
	get_tree().connect("network_peer_disconnected", self, "_player_disconnected")
	if hostipnumber == "":
		networkedmultiplayerenet.create_server(hostportnumber, 5)
		playerMe.connectiontoserveractive = (not arvr_quest)
	else:
		networkedmultiplayerenet.create_client(hostipnumber, hostportnumber)
		get_tree().connect("connected_to_server", self, "_connected_to_server")
		get_tree().connect("connection_failed", self, "_connection_failed")
		get_tree().connect("server_disconnected", self, "_server_disconnected")
		playerMe.connectiontoserveractive = false
		#playerMe.rotate_y(180)  
		playerMe.global_transform.origin += 3*Vector3(playerMe.get_node("HeadCam").global_transform.basis.z.x, 0, playerMe.get_node("HeadCam").global_transform.basis.z.z).normalized()
	get_tree().set_network_peer(networkedmultiplayerenet)
	networkID = get_tree().get_network_unique_id()
	print("nnet-id ", networkID)
	playerMe.set_network_master(networkID)
	playerMe.networkID = networkID

	$GuiSystem/GUIPanel3D/Viewport/GUI/Panel/ButtonUpdateShell.pressed = true
	$GuiSystem/GUIPanel3D._on_buttonupdateshell_toggled(true)


func nextplayernetworkidinringskippingdoppelganger(deletedid):
	for i in range($Players.get_child_count()):
		var nextringplayer = $Players.get_child((playerMe.get_index()+1)%$Players.get_child_count())
		if deletedid == 0 or nextringplayer.networkID != deletedid:
			if nextringplayer.networkID != 0:
				return nextringplayer.networkID
	return 0
	
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
		playerOther.networkID = id
		$Players.add_child(playerOther)
	if networkID == 1:
		$SketchSystem.rpc_id(id, "sketchsystemfromdict", $SketchSystem.sketchsystemtodict())
	playerMe.bouncetestnetworkID = nextplayernetworkidinringskippingdoppelganger(0)
	
func _player_disconnected(id):
	print("_player_disconnected ", id)
	var playerothername = "NetworkedPlayer"+String(id)
	print("Number of players before queuefree ", $Players.get_child_count())
	if $Players.has_node(playerothername):
		$Players.get_node(playerothername).queue_free()
	print("Number of players after queuefree ", $Players.get_child_count())
	playerMe.bouncetestnetworkID = nextplayernetworkidinringskippingdoppelganger(id)
		
func _connected_to_server():
	print("_connected_to_server")
	playerMe.connectiontoserveractive = true 
	
	
func _connection_failed():
	print("_connection_failed")
func _server_disconnected():
	print("_server_disconnected")
	playerMe.connectiontoserveractive = false
	
func _process(_delta):
	if !perform_runtime_config:
		ovr_performance.set_clock_levels(1, 1)
		ovr_performance.set_extra_latency_mode(1)
		perform_runtime_config = true
		set_process(false)

func clearallprocessactivityforreload():
	$LabelGenerator.workingxcnode = null
	$LabelGenerator.remainingxcnodes.clear()
	$ImageSystem.fetcheddrawing = null
	$ImageSystem.paperdrawinglist.clear()

	var pointersystem = playerMe.get_node("pointersystem")
	pointersystem.clearactivetargetnode()  # clear all the objects before they are freed
	#pointersystem.clearpointertargetmaterial()
	pointersystem.pointertarget = null
	pointersystem.pointertargettype = "none"
	pointersystem.pointertargetwall = null
	pointersystem.activetargetwall = null
	pointersystem.activetargetwallgrabbedtransform = null


