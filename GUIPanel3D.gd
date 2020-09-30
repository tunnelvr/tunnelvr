extends StaticBody


var viewport_point := Vector2(0, 0)
var viewport_mousedown := false
onready var sketchsystem = get_node("/root/Spatial/SketchSystem")

func _on_buttonload_pressed():
	var savegamefileid = $Viewport/GUI/Panel/Savegamefilename.get_selected_id()
	var savegamefilename = "user://"+$Viewport/GUI/Panel/Savegamefilename.get_item_text(savegamefileid)
	if not File.new().file_exists(savegamefilename):
		$Viewport/GUI/Panel/Label.text = savegamefilename + " does not exist"
		return
	sketchsystem.loadsketchsystem(savegamefilename)
	$Viewport/GUI/Panel/Label.text = "Sketch Loaded"
	
func _on_buttonsave_pressed():
	var savegamefileid = $Viewport/GUI/Panel/Savegamefilename.get_selected_id()
	var savegamefilename = "user://"+$Viewport/GUI/Panel/Savegamefilename.get_item_text(savegamefileid)
	sketchsystem.savesketchsystem(savegamefilename)
	$Viewport/GUI/Panel/Label.text = "Sketch Saved"

func _on_buttonfetchimages_pressed():
	get_node("/root/Spatial/ImageSystem").fetchimportpapers()
	$Viewport/GUI/Panel/Label.text = "Papers fetching"

func _on_buttonplanview_toggled(button_pressed):
	get_node("/root/Spatial/PlanViewSystem").setplanviewvisible(button_pressed, global_transform, $Quad.mesh.size)
	$Viewport/GUI/Panel/Label.text = "Planview on" if button_pressed else "Planview off"
	
func _on_buttonheadtorch_toggled(button_pressed):
	get_node("/root/Spatial").playerMe.setheadtorchlight(button_pressed)
	$Viewport/GUI/Panel/Label.text = "Headtorch on" if button_pressed else "Headtorch off"
	if not Tglobal.controlslocked:
		toggleguipanelvisibility(null)

func _on_buttondoppelganger_toggled(button_pressed):
	get_node("/root/Spatial").playerMe.setdoppelganger(button_pressed)
	$Viewport/GUI/Panel/Label.text = "Doppelganger on" if button_pressed else "Doppelganger off"
	if not Tglobal.controlslocked:
		toggleguipanelvisibility(null)

func _on_buttonlockcontrols_toggled(button_pressed):
	Tglobal.controlslocked = button_pressed
	$Viewport/GUI/Panel/Label.text = "Controls locked" if button_pressed else "Controls unlocked"
	if not Tglobal.controlslocked:
		toggleguipanelvisibility(null)

func _on_centrelinevisibility_selected(index):
	var cvsel = $Viewport/GUI/Panel/CentrelineVisibility.get_item_text(index)
	if cvsel == "show":
		Tglobal.centrelinevisible = true
		Tglobal.centrelineonly = false
	if cvsel == "only":
		Tglobal.centrelinevisible = true
		Tglobal.centrelineonly = true
	if cvsel == "hide":
		Tglobal.centrelinevisible = false
		Tglobal.centrelineonly = false
	sketchsystem.updatecentrelinevisibility()
	$Viewport/GUI/Panel/Label.text = "Centrelines: "+cvsel

func _on_xcdrawingvisibility_selected(index):
	var cvsel = $Viewport/GUI/Panel/XCdrawingVisibility.get_item_text(index)
	if cvsel == "show":
		Tglobal.tubedxcsvisible = true
		Tglobal.tubeshellsvisible = true
	if cvsel == "only":
		Tglobal.tubedxcsvisible = true
		Tglobal.tubeshellsvisible = false
	if cvsel == "hide" or cvsel == "hide2":
		Tglobal.tubedxcsvisible = false
		Tglobal.tubeshellsvisible = true
	sketchsystem.changetubedxcsvizmode()
	sketchsystem.updateworkingshell()
	$Viewport/GUI/Panel/Label.text = "XCdrawings: "+cvsel


func _on_buttonswapcontrollers_pressed():
	get_node("/root/Spatial").playerMe.swapcontrollers()
	$Viewport/GUI/Panel/Label.text = "Controllers swapped"

func _on_buttonrecord_down():
	$Viewport/GUI/Panel/Label.text = "Recording ***"
	Tglobal.soundsystem.startmyvoicerecording()

func _on_buttonrecord_up():
	var rleng = Tglobal.soundsystem.stopmyvoicerecording()
	$Viewport/GUI/Panel/Label.text = "Recorded  %.0fKb" % (rleng/1000)

func _on_buttonplay_pressed():
	Tglobal.soundsystem.playmyvoicerecording()
	$Viewport/GUI/Panel/Label.text = "Play voice"
	
func _on_buttonload_choke():
	get_node("/root/Spatial/BodyObjects/PlayerMotion").bouldercount = 50
	$Viewport/GUI/Panel/Label.text = "Boulder choke!"
	toggleguipanelvisibility(null)
		
func _ready():
	$Viewport/GUI/Panel/ButtonLoad.connect("pressed", self, "_on_buttonload_pressed")
	$Viewport/GUI/Panel/ButtonSave.connect("pressed", self, "_on_buttonsave_pressed")
	$Viewport/GUI/Panel/ButtonPlanView.connect("toggled", self, "_on_buttonplanview_toggled")
	$Viewport/GUI/Panel/ButtonFetchImages.connect("pressed", self, "_on_buttonfetchimages_pressed")
	$Viewport/GUI/Panel/ButtonHeadtorch.connect("toggled", self, "_on_buttonheadtorch_toggled")
	$Viewport/GUI/Panel/ButtonDoppelganger.connect("toggled", self, "_on_buttondoppelganger_toggled")
	$Viewport/GUI/Panel/ButtonSwapControllers.connect("pressed", self, "_on_buttonswapcontrollers_pressed")
	$Viewport/GUI/Panel/ButtonLockControls.connect("toggled", self, "_on_buttonlockcontrols_toggled")
	$Viewport/GUI/Panel/ButtonRecord.connect("button_down", self, "_on_buttonrecord_down")
	$Viewport/GUI/Panel/ButtonRecord.connect("button_up", self, "_on_buttonrecord_up")
	$Viewport/GUI/Panel/ButtonPlay.connect("pressed", self, "_on_buttonplay_pressed")
	$Viewport/GUI/Panel/ButtonChoke.connect("pressed", self, "_on_buttonload_choke")
	
	$Viewport/GUI/Panel/CentrelineVisibility.connect("item_selected", self, "_on_centrelinevisibility_selected")
	$Viewport/GUI/Panel/XCdrawingVisibility.connect("item_selected", self, "_on_xcdrawingvisibility_selected")
	$Viewport/GUI/Panel/Networkstate.connect("item_selected", self, "_on_networkstate_selected")

	if $Viewport/GUI/Panel/Networkstate.selected != 0:  # could record saved settings on disk
		call_deferred("_on_networkstate_selected", $Viewport/GUI/Panel/Networkstate.selected)


func clickbuttonheadtorch():
	$Viewport/GUI/Panel/ButtonHeadtorch.pressed = not $Viewport/GUI/Panel/ButtonHeadtorch.pressed
	_on_buttonheadtorch_toggled($Viewport/GUI/Panel/ButtonHeadtorch.pressed)

func toggleguipanelvisibility(controller_global_transform):
	if not visible and controller_global_transform != null:
		var paneltrans = global_transform
		var controllertrans = controller_global_transform
		var paneldistance = 0.8 if Tglobal.VRoperating else 0.2
		paneltrans.origin = controllertrans.origin - paneldistance*ARVRServer.world_scale*(controllertrans.basis.z)
		var lookatpos = controllertrans.origin - 1.6*ARVRServer.world_scale*(controllertrans.basis.z)
		paneltrans = paneltrans.looking_at(lookatpos, Vector3(0, 1, 0))
		global_transform = paneltrans
		$Viewport/GUI/Panel/Label.text = "Control panel"
		visible = true
		$CollisionShape.disabled = false
	else:
		visible = false	
		$CollisionShape.disabled = true
	
func guipanelsendmousemotion(collision_point, controller_global_transform, controller_trigger):
	var collider_transform = global_transform
	if collider_transform.xform_inv(controller_global_transform.origin).z < 0:
		return # Don't allow pressing if we're behind the GUI.
	
	# Convert the collision to a relative position. 
	var shape_size = $CollisionShape.shape.extents * 2
	var collider_scale = collider_transform.basis.get_scale()
	var local_point = collider_transform.xform_inv(collision_point)
	# this rescaling because of no xform_affine_inv.  https://github.com/godotengine/godot/issues/39433
	local_point /= (collider_scale * collider_scale)
	local_point /= shape_size
	local_point += Vector3(0.5, -0.5, 0) # X is about 0 to 1, Y is about 0 to -1.
	
	# Find the viewport position by scaling the relative position by the viewport size. Discard Z.
	viewport_point = Vector2(local_point.x, -local_point.y) * $Viewport.size
	
	# Send mouse motion to the GUI.
	var event = InputEventMouseMotion.new()
	event.position = viewport_point
	$Viewport.input(event)
	
	# Figure out whether or not we should trigger a click.
	var new_viewport_mousedown := false
	var distance = controller_global_transform.origin.distance_to(collision_point)/ARVRServer.world_scale
	if distance < 0.1:
		new_viewport_mousedown = true # Allow poking the GUI with finger
	else:
		new_viewport_mousedown = controller_trigger
	
	# Send a left click to the GUI depending on the above.
	if new_viewport_mousedown != viewport_mousedown:
		event = InputEventMouseButton.new()
		event.pressed = new_viewport_mousedown
		event.button_index = BUTTON_LEFT
		event.position = viewport_point
		print("vvvv viewport_point ", viewport_point)
		$Viewport.input(event)
		viewport_mousedown = new_viewport_mousedown

func guipanelreleasemouse():
	if viewport_mousedown:
		var event = InputEventMouseButton.new()
		event.button_index = 1
		event.position = viewport_point
		$Viewport.input(event)
		viewport_mousedown = false
		
func _input(event):
	if event is InputEventKey and event.pressed:
		if event.scancode == KEY_L:
			#sketchsystem.loadsketchsystem(savegamefile)
			_on_buttonload_pressed()
		#elif event.scancode == KEY_S:
		#	sketchsystem.savesketchsystem()
		elif event.scancode == KEY_D:
			$Viewport/GUI/Panel/ButtonDoppelganger.pressed = not $Viewport/GUI/Panel/ButtonDoppelganger.pressed
			_on_buttondoppelganger_toggled($Viewport/GUI/Panel/ButtonDoppelganger.pressed)	
		elif event.scancode == KEY_O:
			_on_buttonswapcontrollers_pressed()




#-------------networking system
var websocketserver = null
var websocketclient = null
var networkedmultiplayerenet = null

func _on_networkstate_selected(index):
	var nssel = $Viewport/GUI/Panel/Networkstate.get_item_text(index)
	var selfSpatial = get_node("/root/Spatial")
	print("Select networkstate: ", nssel)
	if nssel == "Check IPnum":
		print("IP local interfaces: ")
		$Viewport/GUI/Panel/Label.text = ""
		for k in IP.get_local_interfaces():
			var ipnum = ""
			for l in k["addresses"]:
				if l.find(".") != -1:
					ipnum = l
			var kf = k["friendly"] + ": " + ipnum
			print(kf)
			if k["friendly"] == "Wi-Fi" or k["friendly"].begins_with("wlan"):
				$Viewport/GUI/Panel/Label.text = kf
			elif k["friendly"] == "Ethernet" and $Viewport/GUI/Panel/Label.text == "":
				$Viewport/GUI/Panel/Label.text = kf
		websocketclient = null
		
	if nssel.begins_with("Network Off"):
		print("not properly implemented")
		if websocketserver != null:
			websocketserver.close()
			# Note: To achieve a clean close, you will need to keep polling until either WebSocketClient.connection_closed or WebSocketServer.client_disconnected is received.
			# Note: The HTML5 export might not support all status codes. Please refer to browser-specific documentation for more details.
			websocketserver = null
		if websocketclient != null:
			websocketclient. disconnect_from_host()
			#websocketclient = null
		if networkedmultiplayerenet != null:
			networkedmultiplayerenet.close()
			networkedmultiplayerenet = null
		Tglobal.connectiontoserveractive = false
		get_tree().set_network_peer(null)
		
	if nssel.begins_with("As Server"):
		get_tree().connect("network_peer_connected", selfSpatial, "_player_connected")
		get_tree().connect("network_peer_disconnected", selfSpatial, "_player_disconnected")
		Tglobal.connectiontoserveractive = true
		if selfSpatial.usewebsockets:
			websocketserver = WebSocketServer.new();
			var e = websocketserver.listen(selfSpatial.hostportnumber, PoolStringArray(), true)
			print("Websocketserverclient listen: ", e)
			get_tree().set_network_peer(websocketserver)
		else:
			networkedmultiplayerenet = NetworkedMultiplayerENet.new()
			var e = networkedmultiplayerenet.create_server(selfSpatial.hostportnumber, 5)
			print("networkedmultiplayerenet createserver: ", e)
			get_tree().set_network_peer(networkedmultiplayerenet)

		selfSpatial.networkID = get_tree().get_network_unique_id()
		print("server networkID: ", selfSpatial.networkID)
		selfSpatial.playerMe.set_name("NetworkedPlayer"+String(selfSpatial.networkID))
		selfSpatial.playerMe.set_network_master(selfSpatial.networkID)
		selfSpatial.playerMe.networkID = selfSpatial.networkID
		$Viewport/GUI/Panel/Label.text = "networkID: "+str(selfSpatial.networkID)
				
	if nssel.begins_with("Client->"):
		selfSpatial.hostipnumber = nssel.replace("Client->", "")
		get_tree().connect("network_peer_connected", selfSpatial, "_player_connected")
		get_tree().connect("network_peer_disconnected", selfSpatial, "_player_disconnected")
		Tglobal.connectiontoserveractive = false
		get_tree().connect("connected_to_server", selfSpatial, "_connected_to_server")
		get_tree().connect("connection_failed", self, "_connection_failed")
		get_tree().connect("server_disconnected", self, "_server_disconnected")
		selfSpatial.playerMe.global_transform.origin += 3*Vector3(selfSpatial.playerMe.get_node("HeadCam").global_transform.basis.z.x, 0, selfSpatial.playerMe.get_node("HeadCam").global_transform.basis.z.z).normalized()
		if selfSpatial.usewebsockets:
			websocketclient = WebSocketClient.new();
			var url = "ws://"+selfSpatial.hostipnumber+":" + str(selfSpatial.hostportnumber)
			var e = websocketclient.connect_to_url(url, PoolStringArray(), true)
			print("Websocketclient connect to: ", url, " ", e, " <<----ERROR " if e != 0 else "")
			get_tree().set_network_peer(websocketclient)
			
		else:
			networkedmultiplayerenet = NetworkedMultiplayerENet.new()
			var e = networkedmultiplayerenet.create_client(selfSpatial.hostipnumber, selfSpatial.hostportnumber)
			print("networkedmultiplayerenet createclient: ", e)
			get_tree().set_network_peer(networkedmultiplayerenet)
		$Viewport/GUI/Panel/Label.text = "connecting "+("websocket" if selfSpatial.usewebsockets else "ENET")
		
func _connection_failed():
	print("_connection_failed ", websocketclient)
	websocketclient = null
	Tglobal.connectiontoserveractive = false
	$Viewport/GUI/Panel/Label.text = "connection_failed"
	
func _server_disconnected():
	print("_server_disconnected ", websocketclient)
	websocketclient = null
	Tglobal.connectiontoserveractive = false
	$Viewport/GUI/Panel/Label.text = "server_disconnected"

func _process(delta):
	if websocketserver != null and websocketserver.is_listening():
		websocketserver.poll()
	if websocketclient != null and (websocketclient.get_connection_status() == NetworkedMultiplayerPeer.CONNECTION_CONNECTED or websocketclient.get_connection_status() == NetworkedMultiplayerPeer.CONNECTION_CONNECTING):
		websocketclient.poll()


