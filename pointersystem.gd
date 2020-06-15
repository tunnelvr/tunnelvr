extends Spatial

# this has a pointer sphere added JGT
# (and a lot of other hacking)

# variables set by the Spatial.gd
var drawnfloor = null
var drawingwall = null
var sketchsystem = null
var centrelinesystem =null
var nodeorientationpreview = null

var guipanel3d = null
var _is_activating_gui = false
var viewport_point = null

enum Buttons { VR_TRIGGER = 15, VR_PAD=14, VR_BUTTON_BY=1, VR_GRIP=2 }
onready var controller = get_parent()
var distance = 50

# Need to replace this with proper solution once support for layer selection has been added 
#export (int, FLAGS, "Layer 1", "Layer 2", "Layer 3", "Layer 4", "Layer 5", "Layer 6", "Layer 7", "Layer 8", "Layer 9", "Layer 10", "Layer 11", "Layer 12", "Layer 13", "Layer  14", "Layer 15", "Layer 16", "Layer 17", "Layer 18", "Layer 19", "Layer 20") 
var collision_mask = 14 

const OnePathNode = preload("res://nodescenes/OnePathNode.tscn")

var pointinghighlightmaterial = SpatialMaterial.new()
var selectedhighlightmaterial = SpatialMaterial.new()
var selectedpointerhighlightmaterial = SpatialMaterial.new()

var pointertarget = null
var pointertargetpoint = Vector3(0, 0, 0)
var pointertargetoriginy = 0.0
var selectedtarget = null
var gripbuttonpressused = false
var nodeorientationpreviewheldtransform = null
var drawingwallangle = 0.0

# set_materialoverride

onready var LaserSquare = get_node("../../../LaserSquare")
onready var LaserSpot = get_node("LaserSpot"); 
onready var LaserSpike = get_node("LaserSpot/LaserSpike"); 

var laser_y = -0.05

onready var ARVRworld_scale = ARVRServer.world_scale

func set_collision_mask(p_new_mask):
	collision_mask = p_new_mask
	print("collision_maskcollision_maskcollision_mask ", collision_mask)
	if $Laser:
		$Laser/RayCast.collision_mask = collision_mask

func settextpanel(ltext, pos):
	var textpanel = sketchsystem.get_node("Centreline/TextPanel")
	if ltext != null:
		textpanel.get_node("Viewport/Label").text = ltext
		textpanel.global_transform.origin = pos + Vector3(0, 0.3, 0)
		textpanel.visible = true
	else:
		textpanel.visible = false

func _ready():
	get_parent().connect("button_pressed", self, "_on_button_pressed")
	get_parent().connect("button_release", self, "_on_button_release")
	print("LaserSquare ", LaserSquare)
	print("LaserSpot ", LaserSpot)
	pointinghighlightmaterial.albedo_color = Color(0.99, 0.20, 0.20, 1.0)
	pointinghighlightmaterial.flags_no_depth_test = true
	selectedhighlightmaterial.albedo_color = Color(0.92, 0.99, 0.13, 1.0)
	selectedpointerhighlightmaterial.albedo_color = Color(0.82, 0.99, 0.93, 1.0)
	selectedpointerhighlightmaterial.flags_no_depth_test = true
	
	# apply our world scale to our laser position
	$Laser.translation.y = laser_y * ARVRworld_scale
	
	# init our state
	print("in the pointer onready")
	$Laser.mesh.size.z = distance
	$Laser.translation.z = distance * -0.5
	$Laser/RayCast.translation.z = distance * 0.5
	$Laser/RayCast.cast_to.z = -distance

func setopnpos(opn, p, bonfloor):
	opn.global_transform.origin = p
	var floorsize = drawnfloor.get_node("MeshInstance").mesh.size
	var dfinv = drawnfloor.global_transform.affine_inverse()
	var afloorpoint = dfinv.xform(p)
	opn.uvpoint = Vector2(afloorpoint.x/floorsize.x + 0.5, afloorpoint.z/floorsize.y + 0.5)
	opn.drawingname = drawnfloor.get_node("MeshInstance").mesh.material.albedo_texture.resource_path
	if opn.getnodetype() == "ntPath":
		opn.wallangle = 0.0
		if not bonfloor:
			opn.wallangle = drawingwallangle
			opn.global_transform = Transform(Basis(Vector3(0,1,0), drawingwallangle).scaled(Vector3(1,0.2,1)), p)
		else:
			opn.global_transform.origin = p + Vector3(0, 0.2, 0)
			opn.scale.y = opn.global_transform.origin.y
		sketchsystem.ot.copyopntootnode(opn)
		sketchsystem.ot.nodeinwardvecs[opn.otIndex] = LaserSpike.global_transform.basis.y.normalized()
		print("Thislaserspike ", LaserSpike.global_transform.basis.y)
		
func onpointing(newpointertarget, newpointertargetpoint):
	if newpointertarget != pointertarget:
		if is_instance_valid(pointertarget) and pointertarget == guipanel3d:
			guipanel3d.guipanelreleasemouse()
		
		if is_instance_valid(pointertarget) and pointertarget.has_method("set_materialoverride"):
			pointertarget.set_materialoverride(selectedhighlightmaterial if pointertarget == selectedtarget else null)
			if pointertarget.global_transform.origin.y != pointertargetoriginy:
				sketchsystem.updateonepaths()

		pointertarget = newpointertarget
		if is_instance_valid(pointertarget):
			if pointertarget.has_method("set_materialoverride"):
				pointertarget.set_materialoverride(selectedpointerhighlightmaterial if pointertarget == selectedtarget else pointinghighlightmaterial)
				LaserSpot.visible = false
				pointertargetoriginy = pointertarget.global_transform.origin.y
			elif pointertarget == guipanel3d:
				LaserSpot.visible = false
			else:
				LaserSpot.visible = true
		else:
			LaserSpot.visible = false
	pointertargetpoint = newpointertargetpoint
	if is_instance_valid(pointertarget) and pointertarget == guipanel3d:
		guipanel3d.guipanelsendmousemotion(pointertargetpoint, controller.global_transform, controller.is_button_pressed(Buttons.VR_TRIGGER))

	if LaserSpot.visible:
		LaserSpot.global_transform.origin = pointertargetpoint


func _on_button_pressed(p_button):
	print("pppp ", pointertargetpoint)
	if p_button == Buttons.VR_BUTTON_BY:
		guipanel3d.togglevisibility(controller.get_node("pointersystem").global_transform)
			
	if p_button == Buttons.VR_TRIGGER and is_instance_valid(pointertarget):
		print("clclc ", pointertarget.get_filename(), pointertarget.get_parent())
		if pointertarget.has_method("jump_up"):
			pointertarget.jump_up()
			
		elif pointertarget == guipanel3d:
			pass  #this is elsewhere processed

		elif pointertarget == nodeorientationpreview:
			nodeorientationpreviewheldtransform = get_parent().global_transform.inverse()

		elif pointertarget == drawnfloor or pointertarget == drawingwall:
			var bonfloor = (pointertarget == drawnfloor)
			# drag node to new position on floor
			if controller.is_button_pressed(Buttons.VR_GRIP) and is_instance_valid(selectedtarget) and selectedtarget.has_method("set_materialoverride"):
				if selectedtarget.getnodetype() == "ntPath":
					setopnpos(selectedtarget, pointertargetpoint, bonfloor)
					sketchsystem.updateonepaths()
				if selectedtarget.getnodetype() == "ntDrawnStation" and bonfloor:
					setopnpos(selectedtarget, pointertargetpoint, bonfloor)
				gripbuttonpressused = true
				
			# new drawn station node on floor with centreline node already connected
			elif is_instance_valid(selectedtarget) and selectedtarget.getnodetype() == "ntStation" and bonfloor:
				pointertarget = centrelinesystem.newdrawnstationnode()
				setopnpos(pointertarget, pointertargetpoint, true)
				pointertarget.stationname = selectedtarget.stationname
				selectedtarget.set_materialoverride(null)
				selectedtarget = null
				settextpanel(null, null)
				
			# new node on floor, with or without other node selected to connect to
			else:
				pointertarget = sketchsystem.newonepathnode(-1)
				setopnpos(pointertarget, pointertargetpoint, bonfloor)
				if is_instance_valid(selectedtarget) and selectedtarget.getnodetype() == "ntPath":
					if bonfloor:
						pointertarget.global_transform.origin.y = selectedtarget.global_transform.origin.y
						pointertarget.scale.y = pointertarget.global_transform.origin.y
						sketchsystem.ot.copyopntootnode(pointertarget)
					sketchsystem.applyonepath(selectedtarget, pointertarget)
					selectedtarget.set_materialoverride(null)
				elif bonfloor:
					pointertarget.global_transform.origin.y = 0.2
					pointertarget.scale.y = pointertarget.global_transform.origin.y
					sketchsystem.ot.copyopntootnode(pointertarget)
					
				if controller.is_button_pressed(Buttons.VR_GRIP):
					selectedtarget = null
					nodeorientationpreview.visible = false
					nodeorientationpreview.get_node("CollisionShape").disabled = true
				else:
					selectedtarget = pointertarget
					selectedtarget.set_materialoverride(selectedpointerhighlightmaterial)
					nodeorientationpreview.global_transform = sketchsystem.ot.nodeplanetransform(selectedtarget.otIndex)
					nodeorientationpreview.visible = true
					nodeorientationpreview.get_node("CollisionShape").disabled = false
				assert (sketchsystem.ot.verifyonetunnelmatches(sketchsystem))

					
		# clear selected target by selecting again
		# (we may reconsider deselection on second selection)
		elif pointertarget == selectedtarget:
			if selectedtarget.getnodetype() == "ntStation":
				settextpanel(null, null)
			elif selectedtarget.getnodetype() == "ntPath":
				nodeorientationpreview.visible = false
				nodeorientationpreview.get_node("CollisionShape").disabled = true
			selectedtarget.set_materialoverride(pointinghighlightmaterial)
			if controller.is_button_pressed(Buttons.VR_GRIP):
				if selectedtarget.getnodetype() == "ntPath":
					sketchsystem.removeonepathnode(selectedtarget)
				elif selectedtarget.getnodetype() == "ntDrawnStation":
					selectedtarget.queue_free()

				gripbuttonpressused = true
			selectedtarget = null
			
		# click on new selected target (connect from previous selected target)
		else:
			if is_instance_valid(selectedtarget) and selectedtarget.has_method("set_materialoverride"):
				selectedtarget.set_materialoverride(null)
				if selectedtarget.getnodetype() == "ntStation":
					nodeorientationpreview.visible = false
					nodeorientationpreview.get_node("CollisionShape").disabled = true
					settextpanel(null, null)
				if selectedtarget.getnodetype() == "ntPath" and pointertarget.getnodetype() == "ntPath":
					sketchsystem.applyonepath(selectedtarget, pointertarget)

			selectedtarget = pointertarget
			selectedtarget.set_materialoverride(selectedpointerhighlightmaterial)
			if selectedtarget.getnodetype() == "ntStation":
				settextpanel(selectedtarget.stationname, selectedtarget.global_transform.origin)
			elif selectedtarget.getnodetype() == "ntDrawnStation":
				settextpanel(selectedtarget.stationname, centrelinesystem.stationnodemap[selectedtarget.stationname].global_transform.origin)				
			elif selectedtarget.getnodetype() == "ntPath":
				nodeorientationpreview.global_transform = sketchsystem.ot.nodeplanetransform(selectedtarget.otIndex)
				nodeorientationpreview.visible = true
				nodeorientationpreview.get_node("CollisionShape").disabled = false
				sketchsystem.get_node("NodePreview").mesh = sketchsystem.ot.nodeplanepreview(selectedtarget.otIndex)
				
	# change height of pointer target
	if p_button == Buttons.VR_PAD and is_instance_valid(pointertarget) and ((pointertarget.has_method("set_materialoverride") and pointertarget.has_method("getnodetype") and pointertarget.getnodetype() == "ntPath" and pointertarget.wallangle == 0.0) or (pointertarget == drawingwall)):
		var left_right = controller.get_joystick_axis(0)
		var up_down = controller.get_joystick_axis(1)
		if abs(up_down) < 0.5 and abs(left_right) > 0.1:
			pointertarget.global_transform.origin.y = max(0.1, pointertarget.global_transform.origin.y + (1 if left_right > 0 else -1)*(1.0 if abs(left_right) < 0.8 else 0.1))
			pointertarget.scale.y = pointertarget.global_transform.origin.y
			if (pointertarget != drawingwall):
				sketchsystem.ot.copyopntootnode(pointertarget)
				nodeorientationpreview.global_transform.origin = pointertarget.global_transform.origin
			
	if p_button == Buttons.VR_GRIP:
		gripbuttonpressused = false

func _on_button_release(p_button):
	# cancel selection by squeezing and then releasing grip without doing anything in between
	if p_button == Buttons.VR_GRIP and not gripbuttonpressused and is_instance_valid(selectedtarget) and selectedtarget.has_method("set_materialoverride"):
		selectedtarget.set_materialoverride(pointinghighlightmaterial if selectedtarget == pointertarget else null)
		selectedtarget = null
		if nodeorientationpreview.visible:
			nodeorientationpreview.visible = false
			nodeorientationpreview.get_node("CollisionShape").disabled = true
			nodeorientationpreviewheldtransform = null
		
	elif p_button == Buttons.VR_TRIGGER and (nodeorientationpreviewheldtransform != null):
		print("dosomethingwith nodeorientationpreview ", nodeorientationpreviewheldtransform)
		var oiv = sketchsystem.ot.nodeinwardvecs[selectedtarget.otIndex]
		var iv = get_parent().global_transform.basis.xform(nodeorientationpreviewheldtransform.basis.xform(oiv))
		sketchsystem.ot.nodeinwardvecs[selectedtarget.otIndex] = iv
		nodeorientationpreviewheldtransform = null

	elif p_button == Buttons.VR_TRIGGER and is_instance_valid(selectedtarget) and is_instance_valid(pointertarget) and pointertarget.has_method("set_materialoverride") and pointertarget != selectedtarget:
		var vwall = pointertarget.global_transform.origin - selectedtarget.global_transform.origin
		var vwall2 = Vector2(vwall.x, vwall.z)
		drawingwallangle = -vwall2.angle()
		var vwallsca = vwall2.length()
		if vwallsca != 0.0:
			drawingwall.global_transform = Transform(Basis().scaled(Vector3(vwallsca,selectedtarget.global_transform.origin.y,1)).rotated(Vector3(0,1,0), drawingwallangle), selectedtarget.global_transform.origin)
			
func _process(_delta):
	if !is_inside_tree():
		return
	if nodeorientationpreviewheldtransform != null:
		var oiv = sketchsystem.ot.nodeinwardvecs[selectedtarget.otIndex]
		var iv = get_parent().global_transform.basis.xform(nodeorientationpreviewheldtransform.basis.xform(oiv))
		var iv0 = iv.cross(Vector3(0, 0, 1)).normalized()
		if iv0.length_squared() == 0:
			iv0 = iv.cross(Vector3(1, 0, 0))
		var iv1 = iv0.cross(iv)
		# here could add the 3D push pull motions too
		nodeorientationpreview.global_transform = Transform(Basis(iv0, iv, iv1), sketchsystem.ot.nodepoints[selectedtarget.otIndex])
	elif $Laser/RayCast.is_colliding():
		onpointing($Laser/RayCast.get_collider(), $Laser/RayCast.get_collision_point())
	else:
		onpointing(null, null)
	
