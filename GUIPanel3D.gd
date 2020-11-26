extends StaticBody


var collision_point := Vector3(0, 0, 0)
var viewport_point := Vector2(0, 0)
var viewport_mousedown := false
onready var sketchsystem = get_node("/root/Spatial/SketchSystem")
onready var playerMe = get_node("/root/Spatial/Players/PlayerMe")

func _on_buttonload_pressed():
	var savegamefileid = $Viewport/GUI/Panel/Savegamefilename.get_selected_id()
	var savegamefilename = $Viewport/GUI/Panel/Savegamefilename.get_item_text(savegamefileid)
	if savegamefilename.begins_with("server/"):
		savegamefilename = savegamefilename.replace("server/", "")
		if Tglobal.connectiontoserveractive and playerMe.networkID != 1:
			sketchsystem.rpc_id(1, "loadsketchsystemL", "user://"+savegamefilename)
			$Viewport/GUI/Panel/Label.text = "Loading server sketch"
			return
	var savegamefilenameU = "user://"+savegamefilename
	if File.new().file_exists(savegamefilenameU):
		sketchsystem.loadsketchsystemL(savegamefilenameU)
		$Viewport/GUI/Panel/Label.text = "Sketch Loaded"
		if not Tglobal.controlslocked:
			toggleguipanelvisibility(null)
	else:
		$Viewport/GUI/Panel/Label.text = savegamefilename + " does not exist"
	Tglobal.soundsystem.quicksound("MenuClick", collision_point)
	
func _on_buttonsave_pressed():
	var savegamefileid = $Viewport/GUI/Panel/Savegamefilename.get_selected_id()
	var savegamefilename = $Viewport/GUI/Panel/Savegamefilename.get_item_text(savegamefileid)
	if savegamefilename.begins_with("server/"):
		savegamefilename = savegamefilename.replace("server/", "")
		if Tglobal.connectiontoserveractive and playerMe.networkID != 1:
			sketchsystem.rpc_id(1, "savesketchsystem", "user://"+savegamefilename)
			$Viewport/GUI/Panel/Label.text = "Saving server sketch"
			return
	var savegamefilenameU = "user://"+savegamefilename
	sketchsystem.savesketchsystem(savegamefilenameU)
	$Viewport/GUI/Panel/Label.text = "Sketch Saved"
	Tglobal.soundsystem.quicksound("MenuClick", collision_point)
	

func _on_buttonplanview_pressed():
	var pvchange = { "visible":$Viewport/GUI/Panel/ButtonPlanView.pressed }
	var planviewsystem = get_node("/root/Spatial/PlanViewSystem")
	if pvchange["visible"]:
		var guidpaneltransform = global_transform
		var guidpanelsize = $Quad.mesh.size
		if not Tglobal.controlslocked:
			toggleguipanelvisibility(null)
			guidpaneltransform = null
		pvchange["transformpos"] = planviewsystem.planviewtransformpos(guidpaneltransform, guidpanelsize)
		pvchange["planviewactive"] = true
		#pvchange[""]
		sketchsystem.actsketchchange([{"planview":pvchange}])
	else:
		pvchange["planviewactive"] = false
		#pvchange[""]
		sketchsystem.actsketchchange([{"planview":pvchange}])
	pvchange["tubesvisible"] = planviewsystem.planviewcontrols.get_node("CheckBoxTubesVisible").pressed 
	$Viewport/GUI/Panel/Label.text = "Planview on" if pvchange["visible"] else "Planview off"
	Tglobal.soundsystem.quicksound("MenuClick", collision_point)
	if not Tglobal.controlslocked:
		toggleguipanelvisibility(null)
	
func _on_buttonheadtorch_toggled(button_pressed):
	playerMe.setheadtorchlight(button_pressed)
	$Viewport/GUI/Panel/Label.text = "Headtorch on" if button_pressed else "Headtorch off"
	if not Tglobal.controlslocked:
		toggleguipanelvisibility(null)

func _on_buttondoppelganger_toggled(button_pressed):
	playerMe.setdoppelganger(button_pressed)
	$Viewport/GUI/Panel/Label.text = "Doppelganger on" if button_pressed else "Doppelganger off"
	if not Tglobal.controlslocked:
		toggleguipanelvisibility(null)

func _on_buttonlockcontrols_toggled(button_pressed):
	Tglobal.controlslocked = button_pressed
	$Viewport/GUI/Panel/Label.text = "Controls locked" if button_pressed else "Controls unlocked"
	if not Tglobal.controlslocked:
		toggleguipanelvisibility(null)
	Tglobal.soundsystem.quicksound("MenuClick", collision_point)

func _on_buttonflywalkreversed_toggled(button_pressed):
	get_node("/root/Spatial/BodyObjects/PlayerDirections").flywalkreversed = button_pressed
	$Viewport/GUI/Panel/Label.text = "Fly/Walk reversed" if button_pressed else "Fly/Walk normal"
	if not Tglobal.controlslocked:
		toggleguipanelvisibility(null)


func _on_playerscale_selected(index):
	var newplayerscale = float($Viewport/GUI/Panel/WorldScale.get_item_text(index))
	ARVRServer.world_scale = newplayerscale
	playerMe.playerscale = newplayerscale
	playerMe.get_node("HandLeft").setcontrollerhandtransform(playerMe.playerscale)
	playerMe.get_node("HandRight").setcontrollerhandtransform(playerMe.playerscale)
	if playerMe.playerscale == 1.0:
		get_node("/root/Spatial/BodyObjects/PlayerDirections").forceontogroundtimedown = 0.25
		playerMe.playerflyscale = 1.0
	else:
		if playerMe.playerscale >= 10:
			playerMe.playerflyscale = playerMe.playerscale*0.2
		else:
			playerMe.playerflyscale = playerMe.playerscale*0.75
	toggleguipanelvisibility(null)
	
func _on_msaa_selected(index):
	get_node("/root/Spatial").setmsaa()

func _on_buttonswapcontrollers_pressed():
	playerMe.swapcontrollers()
	$Viewport/GUI/Panel/Label.text = "Controllers swapped"
	Tglobal.soundsystem.quicksound("MenuClick", collision_point)

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
	get_node("/root/Spatial/BodyObjects/PlayerMotion").makeboulderchoke(50)
	$Viewport/GUI/Panel/Label.text = "Boulder choke!"
	toggleguipanelvisibility(null)

const clientips = [ "144.76.167.54 Alex",  # alex server
					"192.168.43.186 Quest2",  # quest on j's phone
					"192.168.43.172 JGT", 
					"192.168.43.118" ]
func _ready():
	if has_node("ViewportReal"):
		var fgui = $Viewport/GUI
		$Viewport.remove_child(fgui)
		$ViewportReal.add_child(fgui)
		$Viewport.set_name("ViewportFake")
		$ViewportReal.set_name("Viewport")
		$Quad.get_surface_material(0).albedo_texture = $Viewport.get_texture()
		
	for clientip in clientips:
		$Viewport/GUI/Panel/Networkstate.add_item("Client->"+clientip)
	
	$Viewport/GUI/Panel/ButtonLoad.connect("pressed", self, "_on_buttonload_pressed")
	$Viewport/GUI/Panel/ButtonSave.connect("pressed", self, "_on_buttonsave_pressed")
	$Viewport/GUI/Panel/ButtonPlanView.connect("pressed", self, "_on_buttonplanview_pressed")
	$Viewport/GUI/Panel/ButtonHeadtorch.connect("toggled", self, "_on_buttonheadtorch_toggled")
	$Viewport/GUI/Panel/ButtonDoppelganger.connect("toggled", self, "_on_buttondoppelganger_toggled")
	$Viewport/GUI/Panel/ButtonSwapControllers.connect("pressed", self, "_on_buttonswapcontrollers_pressed")
	$Viewport/GUI/Panel/ButtonLockControls.connect("toggled", self, "_on_buttonlockcontrols_toggled")
	$Viewport/GUI/Panel/FlyWalkReversed.connect("toggled", self, "_on_buttonflywalkreversed_toggled")
	#$Viewport/GUI/Panel/ButtonRecord.connect("button_down", self, "_on_buttonrecord_down")
	#$Viewport/GUI/Panel/ButtonRecord.connect("button_up", self, "_on_buttonrecord_up")
	#$Viewport/GUI/Panel/ButtonPlay.connect("pressed", self, "_on_buttonplay_pressed")
	$Viewport/GUI/Panel/ButtonChoke.connect("pressed", self, "_on_buttonload_choke")
	
	$Viewport/GUI/Panel/MSAAstatus.connect("item_selected", self, "_on_msaa_selected")
	$Viewport/GUI/Panel/PlayerList.connect("item_selected", self, "_on_playerlist_selected")
	$Viewport/GUI/Panel/ButtonGoto.connect("pressed", self, "_on_buttongoto_pressed")
	$Viewport/GUI/Panel/WorldScale.connect("item_selected", self, "_on_playerscale_selected")
	$Viewport/GUI/Panel/Networkstate.connect("item_selected", self, "_on_networkstate_selected")

	if $Viewport/GUI/Panel/Networkstate.selected != 0:  # could record saved settings on disk
		call_deferred("_on_networkstate_selected", $Viewport/GUI/Panel/Networkstate.selected)

func clickbuttonheadtorch():
	$Viewport/GUI/Panel/ButtonHeadtorch.pressed = not $Viewport/GUI/Panel/ButtonHeadtorch.pressed
	_on_buttonheadtorch_toggled($Viewport/GUI/Panel/ButtonHeadtorch.pressed)


var selectedplayernetworkid = 0
var selectedplayerplatform = ""
func _on_goto_pressed():
	if selectedplayernetworkid == playerMe.networkID:
		if playerMe.networkID != 1 and Tglobal.connectiontoserveractive:
			playerMe.rpc_id(1, "playerjumpgoto", playerMe.networkID)
	elif selectedplayernetworkid != -1:
		playerMe.playerjumpgoto(selectedplayernetworkid)

func _on_playerlist_selected(index):
	var player = get_node("/root/Spatial/Players").get_child(index)
	if player != null:
		selectedplayernetworkid = player.networkID
		selectedplayerplatform = player.playerplatform
		$Viewport/GUI/Panel/PlayerInfo.text = "%s:%d" % [selectedplayerplatform, selectedplayernetworkid]
		netlinkstatstimer = -3.0
		networkmetricsreceived = null
		$Viewport/GUI/Panel/ButtonGoto.disabled = selectedplayernetworkid == playerMe.networkID and playerMe.networkID == 1

	else:
		selectedplayernetworkid = -1
		selectedplayerplatform = ""
		$Viewport/GUI/Panel/PlayerInfo.text = String("updating")
		updateplayerlist()
		$Viewport/GUI/Panel/ButtonGoto.disabled = true
		
	
func updateplayerlist():
	var selectedplayerindex = 0
	$Viewport/GUI/Panel/PlayerList.clear()
	for player in get_node("/root/Spatial/Players").get_children():
		var playername
		if player == playerMe:
			playername = "me"
		elif player == playerMe.doppelganger:
			playername = "doppel"
		elif player.networkID == 1:
			playername = "server"
		else:
			playername = "player%d" % player.get_index()
		$Viewport/GUI/Panel/PlayerList.add_item(playername)
		
		if player.networkID == selectedplayernetworkid:
			selectedplayerindex = player.get_index()

	$Viewport/GUI/Panel/PlayerList.select(selectedplayerindex)
	

func toggleguipanelvisibility(controller_global_transform):
	if not visible and controller_global_transform != null:
		var paneltrans = Transform()
		var controllertrans = controller_global_transform
		var paneldistance = 0.6 if Tglobal.VRoperating else 0.2
		paneltrans.origin = controllertrans.origin - paneldistance*ARVRServer.world_scale*(controllertrans.basis.z)
		var lookatpos = controllertrans.origin - 1.6*ARVRServer.world_scale*(controllertrans.basis.z)
		paneltrans = paneltrans.looking_at(lookatpos, Vector3(0, 1, 0))
		paneltrans = Transform(paneltrans.basis.scaled(Vector3(ARVRServer.world_scale, ARVRServer.world_scale, ARVRServer.world_scale)), paneltrans.origin)		
		global_transform = paneltrans
		
		$Viewport/GUI/Panel/Label.text = ""
		var MQTTExperiment = get_node_or_null("/root/Spatial/MQTTExperiment")
		if MQTTExperiment != null and MQTTExperiment.msg != "":
			$Viewport/GUI/Panel/Label.text = MQTTExperiment.msg
		elif Tglobal.connectiontoserveractive:
			Tglobal.connectiontoserveractive

		visible = true
		$CollisionShape.disabled = false
		Tglobal.soundsystem.quicksound("ShowGui", global_transform.origin)
	else:
		visible = false	
		$CollisionShape.disabled = true
		var MQTTExperiment = get_node_or_null("/root/Spatial/MQTTExperiment")
		if MQTTExperiment != null and MQTTExperiment.msg != "":
			$Viewport/GUI/Panel/Label.text = MQTTExperiment.msg

	var selfSpatial = get_node("/root/Spatial")
	if Tglobal.connectiontoserveractive:
		print("nnnnn ", get_tree().get_network_unique_id())
		assert(selfSpatial.playerMe.networkID != 0)
		selfSpatial.playerMe.rpc("puppetenableguipanel", transform if visible else null)

		if visible and $Viewport/GUI/Panel/Label.text == "":
			var msg = "NetIDs "+str(selfSpatial.playerMe.networkID)+":"
			for id in selfSpatial.players_connected_list:
				msg += " "+str(id)
			print(msg)
			$Viewport/GUI/Panel/Label.text = msg
			
	if is_instance_valid(selfSpatial.playerMe.doppelganger):
		selfSpatial.playerMe.doppelganger.puppetenableguipanel(transform if visible else null)

	
func guipanelsendmousemotion(lcollision_point, controller_global_transform, controller_trigger):
	collision_point = lcollision_point
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
		#print("vvvv viewport_point ", viewport_point)
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
			_on_buttonload_pressed()
		#elif event.scancode == KEY_S:
		#	sketchsystem.savesketchsystem()
		elif event.scancode == KEY_G:
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
		if websocketserver != null:
			websocketserver.close()
			# Note: To achieve a clean close, you will need to keep polling until either WebSocketClient.connection_closed or WebSocketServer.client_disconnected is received.
			# Note: The HTML5 export might not support all status codes. Please refer to browser-specific documentation for more details.
			websocketserver = null
		if websocketclient != null:
			websocketclient. disconnect_from_host()
			#websocketclient = null
		if networkedmultiplayerenet != null:
			networkedmultiplayerenet.close_connection()
			networkedmultiplayerenet = null
		Tglobal.connectiontoserveractive = false
		get_tree().set_network_peer(null)
		
	if nssel.begins_with("As Server"):
		networkstartasserver(true)
		if selfSpatial.playerMe.networkID == 0:
			$Viewport/GUI/Panel/Label.text = "server failed to start"
		else:
			$Viewport/GUI/Panel/Label.text = "networkID: "+str(selfSpatial.playerMe.networkID)
				
	if nssel.begins_with("Client->"):
		selfSpatial.hostipnumber = nssel.replace("Client->", "")
		if selfSpatial.hostipnumber.find(" "):
			selfSpatial.hostipnumber = selfSpatial.hostipnumber.left(selfSpatial.hostipnumber.find(" "))
		print(selfSpatial.hostipnumber.is_valid_ip_address())
		
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

func networkstartasserver(fromgui):
	if not fromgui:
		yield(get_tree().create_timer(2.0), "timeout")		
	print("Starting as server, ipnumber list:")
	for k in IP.get_local_interfaces():
		var ipnum = ""
		for l in k["addresses"]:
			if l.find(".") != -1:
				ipnum = l
		print(k["friendly"] + ": " + ipnum)
	
	var selfSpatial = get_node("/root/Spatial")	
	get_tree().connect("network_peer_connected", selfSpatial, "_player_connected")
	get_tree().connect("network_peer_disconnected", selfSpatial, "_player_disconnected")
	if selfSpatial.usewebsockets:
		websocketserver = WebSocketServer.new();
		var e = websocketserver.listen(selfSpatial.hostportnumber, PoolStringArray(), true)
		print("Websocketserverclient listen: ", e)
		get_tree().set_network_peer(websocketserver)
		Tglobal.connectiontoserveractive = true
	else:
		networkedmultiplayerenet = NetworkedMultiplayerENet.new()
		var e = networkedmultiplayerenet.create_server(selfSpatial.hostportnumber, 9)
		if e == 0:
			get_tree().set_network_peer(networkedmultiplayerenet)
			Tglobal.connectiontoserveractive = true
		else:
			print("networkedmultiplayerenet createserver Error: ", {ERR_CANT_CREATE:"ERR_CANT_CREATE"}.get(e, e))
			print("*** is there a server running on this port already? ", selfSpatial.hostportnumber)
			$Viewport/GUI/Panel/Networkstate.selected = 0

	var lnetworkID = get_tree().get_network_unique_id()
	selfSpatial.setnetworkidnamecolour(selfSpatial.playerMe, lnetworkID)
	print("server networkID: ", selfSpatial.playerMe.networkID)
		
func _connection_failed():
	var selfSpatial = get_node("/root/Spatial")	
	print("_connection_failed ", Tglobal.connectiontoserveractive, " ", websocketclient, " ", selfSpatial.players_connected_list)
	websocketclient = null
	if Tglobal.connectiontoserveractive:
		_server_disconnected()
	else:
		assert (len(selfSpatial.deferred_player_connected_list) == 0)
		assert (len(selfSpatial.players_connected_list) == 0)
	$Viewport/GUI/Panel/Label.text = "connection_failed"
	
func _server_disconnected():
	print("_server_disconnected ", websocketclient)
	websocketclient = null
	networkedmultiplayerenet = null
	Tglobal.connectiontoserveractive = false
	var selfSpatial = get_node("/root/Spatial")	
	selfSpatial.deferred_player_connected_list.clear()
	$Viewport/GUI/Panel/Label.text = "server_disconnected"
	for id in selfSpatial.players_connected_list:
		print("server_disconnected, calling _player_disconnected on ", id)
		selfSpatial.call_deferred("_player_disconnected", id)
	if $Viewport/GUI/Panel/Networkstate.selected != 0:
		$Viewport/GUI/Panel/Networkstate.selected = 0
	
var networkmetricsreceived = null
remote func recordnetworkmetrics(lnetworkmetricsreceived):
	lnetworkmetricsreceived["ticksback"] = OS.get_ticks_msec()
	networkmetricsreceived = lnetworkmetricsreceived
	#print("recordnetworkmetrics ", networkmetricsreceived)
	
remote func sendbacknetworkmetrics(lnetworkmetrics, networkIDsource):
	var playerOthername = "NetworkedPlayer"+String(networkIDsource) if networkIDsource != -11 else "Doppelganger"
	var playerOther = get_node("/root/Spatial/Players").get_node_or_null(playerOthername)
	if playerOther != null and len(playerOther.puppetpositionstack) != 0:
		lnetworkmetrics["stackduration"] = playerOther.puppetpositionstack[-1]["Ltimestamp"] - OS.get_ticks_msec()*0.001
		print(playerOthername, " stackduration is ", lnetworkmetrics["stackduration"])
	else:
		lnetworkmetrics["stackduration"] = 0.0
	lnetworkmetrics["unixtime"] = OS.get_unix_time()
	if networkIDsource >= 0:
		rpc_id(networkIDsource, "recordnetworkmetrics", lnetworkmetrics)
	elif networkIDsource == -11:
		call_deferred("recordnetworkmetrics", lnetworkmetrics)

				
const netlinkstatstimeinterval = 1.1
var netlinkstatstimer = 0.0
var maxdelta = 0.0
var sumdelta = 0.0
var countframes = 0
func _process(delta):
	if websocketserver != null:
		if websocketserver.is_listening():
			websocketserver.poll()
		if (websocketclient.get_connection_status() == NetworkedMultiplayerPeer.CONNECTION_CONNECTED or websocketclient.get_connection_status() == NetworkedMultiplayerPeer.CONNECTION_CONNECTING):
			websocketclient.poll()
	if visible and Tglobal.connectiontoserveractive:
		if netlinkstatstimer < 0.0 and netlinkstatstimer + delta >= 0:
			$Viewport/GUI/Panel/PlayerInfo.text = "%s:%d" % [selectedplayerplatform, selectedplayernetworkid]
		netlinkstatstimer += delta
		maxdelta = max(delta, maxdelta)
		sumdelta += delta
		countframes += 1

		if netlinkstatstimer > netlinkstatstimeinterval:
			if networkmetricsreceived != null:
				var stacktime = networkmetricsreceived["stackduration"]
				var bouncetime = (networkmetricsreceived["ticksback"] - networkmetricsreceived["ticksout"])*0.001
				$Viewport/GUI/Panel/PlayerInfo.text = "bounce:%.3f stack:%.3f" % [bouncetime, stacktime]
				networkmetricsreceived = null
			elif selectedplayernetworkid == 0 or selectedplayernetworkid == playerMe.networkID:
				if countframes != 0:
					$Viewport/GUI/Panel/PlayerInfo.text = "frame max:%.3f avg:%.3f" % [maxdelta, sumdelta/countframes]
					maxdelta = 0.0
					sumdelta = 0.0
					countframes = 0
			if selectedplayernetworkid >= 0:
				rpc_id(selectedplayernetworkid, "sendbacknetworkmetrics", { "ticksout":OS.get_ticks_msec() }, playerMe.networkID)
			elif selectedplayernetworkid == -10:
				call_deferred("sendbacknetworkmetrics", { "ticksout":OS.get_ticks_msec() }, -11)
			netlinkstatstimer = 0.0
