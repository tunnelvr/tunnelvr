extends Spatial


# Stuff to do:


# * add networking instructions to README


# * PlanViewSystem VR_BY button to toggle activeness
# * PlanViewSystem into own scene created and destroyed
# * PlanViewSystem into PlayerMe
# * PlanViewSystem to make centreline nodes really big so we can pick them out and highlight them
# * experiment with billboard mode on a circular object

# * LaserShadow out in global space under a node

# * LaserScope to be an argument of laser pointer
# * How is the laser scope the a square and it works


# * highlight nodes under pointer system so it's global and simplifies colouring code
# 

# * Pass in shader_params on the tube rock material (maybe outline too)
# * colours of materials to highlight (or set part of cave)

# * Make as if it's selected in the main node point thing (with a new ray cast)

# Put LaserShadow under a node or set_as_toplevel to remove the transform from it

# * use joypos instead of left_right stuff

# * active node to be an overlay
# * is there a node that is in real space and not relative space transform (for laser shadow)

# * Make directory of environments and move them in there using git move

# * Make a frame and set of UI controls and dragging possible on the window onto the world

# * Attach drawings onto centreline nodes.  Move them about in space there

# * Turn on and off the tubes and make the nodes bigger to grab them



# * Label nodes on paper to connect to the centreline nodes
# * Allow drawing nodes on the paper (so we can make cut outs and labels)

# * Camera from above on the whole picture that can scroll around, like a portal

# * pathlines in selected XCdrawing to have no depthtest

# * ConcaveCollision shape always gives a mesh error -- report

# * loading second round of images does not make new nodes (or controls the names properly) 

# * exportxctrpcdata to be primary tube record

# * a gripclick inserts a new XC in the tube that we can orient and move

# * should correspond to the join we have  
# * can set the type of the material (including invisible and no collision, so open on side)


# * Position of the doppelganger other player is queued in its own object by the rpc and only updated on the physics process
# * must find an answer to the var materialscanimage = load("res://surveyscans/scanimagefloor.material")

# * updatetubeshell to know the material colours from xcsectormaterials

# * On the Occulus joystick, a move to the right is equivalent to a click when above 0.9 (but would need to be debounced)

# * may hide/delete all the nodes of an XC not on a selected tube.
# * so the way to find an XC is to click on the tube

# * A selected tube makes the XCnodes bigger?
# * or we can equivalently cycle through the nodes with right and left VR_Pad

# * and XC is visible (or its nodes are) if there is no tube 

# * tube material must be remembered (and one of the materials is blank)
# * active tube selection

# * grip on XCshape then click gets into rotate mode like with papersheets (but preserving upwardness)

# * what's the black papersheet?

# * possibly lose the connecting xcdrawings to floor feature 
# * just have trimmed sheets that can become floors (or xcs)

# * selection node should be a mask on top of the node rather than a change in its material (so we can make it sticky)
# * apply this tech to a vertical marker in an XC wall for positioning it, or cutting new one
# * perfect overhead light so things project down to the correct place

# * put xcresource (and xcname) into mergexcrpcdata

# * hold back laggy motions by 500ms and animate between the positions
# * (simulate this with dodgy doppelganger.  Local game timestamp is OS.get_ticks_usec()

# * some way to see the names of things in the distance

# * put name of image into XCdrawing (incl paper type)

# * give it a default cave in position in the resources

# * save and load xcname and xcresource

# * floordrawing not special

# * pointertargettypes should be an enum for itself
# * LaserRayCast.collision_mask should use an enum

# * xctubesconn and xctubesconnpositioning
# func updatetubeshell(xcdrawings, makevisible):
#	if makevisible:
#		var tubeshellmesh = maketubeshell(xcdrawings)

# * godot docs.  assert returns null from the function it's in when you ignore it

# * could have makexcdpolys cached

# * check out HDR example https://godotengine.org/asset-library/asset/110

# * need to have a file value on XCnode instead of the name to say the paper image because you could have two with same image

# * sort out the textures of the XCs so they are large enough there.  
# * XCs are going to be translated upwards (and the points back down by offset) so we can have them up by the centrelines
# * XCs positioned by centreline, proportion along and angles relative -- always on a segment and length
# *   Like the position of the trimmed horizontal drawing altitude relative to the centreline station 

# * inline copyxcntootnode and copyotnodetoxcn

# * break up and inline xcapplyonepath

# * bring loose papers to me.  Superimpose one paper on another to make a frame

# * papertype should not be environment collision (just pointer collisions)

# * load in all the cross-sections as hexagons we can make -- as tubes to start off

# * duplicate floor trimming out and place at different Z-levels
#			sketchsystem.rpc("xcdrawingfromdict", xcdrawing.exportxcrpcdata())
# * all XCdrawing repositions should communicate.  
#			sketchsystem.rpc("xcdrawingfromdata", xcdrawing.exportxcrpcdata())
# * formalize the exact order of updates of positions of things so we don't get race conditions

# * transmit rpc_reliable when trigger released on the positioning of a papersheet

# * A bit more quest work
#  -- print out left hand transforms and find what's crashing it
#  -- GUIPanel that prints all the gestures and button states
#  -- find list of canned gestures for the buttons used
#  -- disable pad for motions in left hand.  Find what it is to fly
#  -- start making a signal list for the different commands
#  -- what's wrong with the laser spot in the quest
#  -- what is the networking situation
#  -- To rotate hands round to match controllers pointing in -Z thumb +Y, left hand needs rotation (0,-90,90) and right hand needs (0,90,90) 
#  --   Thumb to index finger is Input.is_joy_button_pressed=JOY_OCULUS_AX=7
#  --   Thumb to middle finger is Input.is_joy_button_pressed=JOY_OCULUS_BY=1
#  --   Thumb to ring finger is Input.is_joy_button_pressed=JOY_VR_GRIP=2
#  --   Thumb to pinky is Input.is_joy_button_pressed=JOY_VR_TRIGGER=15
#  --   Unreliably can get 2 or 3 at once.  Touchpad activates briefly, but is usually -1, 1 or 0 when idle
#  --   Fist with thumb sliding from top down along fingers, Input.get_joy_axis(1) -1 -> +1  (axis 0 is not worked out)
# https://developer.oculus.com/learn/hands-design-interactions/
# https://developer.oculus.com/learn/hands-design-ui/
# https://learn.unity.com/tutorial/unit-5-hand-presence-and-interaction?uv=2018.4&courseId=5d955b5dedbc2a319caab9a0#5d96924dedbc2a6236bc1191
# https://www.youtube.com/watch?v=gpQePH-Ffbw


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

# * quest hand tracking https://github.com/GodotVR/godot_oculus_mobile#features

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

	playerMe.get_node("GUIPanel3D/Viewport/GUI/Panel/ButtonUpdateShell").pressed = true
	playerMe.get_node("GUIPanel3D")._on_buttonupdateshell_toggled(true)


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
	
remotesync func ding(t, dd):
	print("ding ding ding ", t)	
	print("currentpath ", get_path())

func _process(_delta):
	if !perform_runtime_config:
		ovr_performance.set_clock_levels(1, 1)
		ovr_performance.set_extra_latency_mode(1)
		perform_runtime_config = true


