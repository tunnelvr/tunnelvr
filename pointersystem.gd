extends Spatial

# this has a pointer sphere added JGT
# (and a lot of other hacking)

# variables set by the 
var drawnfloor = null
var sketchsystem = null

var guipanel3d = null
var _is_activating_gui = false
var viewport_point = null

enum Buttons { VR_TRIGGER = 15, VR_PAD=14, VR_BUTTON_BY=1, VR_GRIP=2 }
onready var controller = get_parent()
var distance = 50

# Need to replace this with proper solution once support for layer selection has been added 
#export (int, FLAGS, "Layer 1", "Layer 2", "Layer 3", "Layer 4", "Layer 5", "Layer 6", "Layer 7", "Layer 8", "Layer 9", "Layer 10", "Layer 11", "Layer 12", "Layer 13", "Layer  14", "Layer 15", "Layer 16", "Layer 17", "Layer 18", "Layer 19", "Layer 20") 
var collision_mask = 14 

const OnePathNode = preload("res://OnePathNode.tscn")

var pointinghighlightmaterial = SpatialMaterial.new()
var selectedhighlightmaterial = SpatialMaterial.new()
var selectedpointerhighlightmaterial = SpatialMaterial.new()

var pointertarget = null
var pointertargetpoint = Vector3(0, 0, 0)
var pointertargetscaley = 0.0
var selectedtarget = null
var gripbuttonpressused = false

# set_materialoverride

onready var LaserSquare = get_node("../../../SketchSystem/LaserSquare")
onready var LaserSpot = get_node("LaserSpot"); 

var laser_y = -0.05

onready var ARVRworld_scale = ARVRServer.world_scale

func set_collision_mask(p_new_mask):
	collision_mask = p_new_mask
	print("collision_maskcollision_maskcollision_mask ", collision_mask)
	if $Laser:
		$Laser/RayCast.collision_mask = collision_mask


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



# Not finished.  To replace the current forced division calculation
func getflooruv(p):
	var collider_scale = drawnfloor.basis.get_scale()
	var local_point = drawnfloor.xform_inv(p)
	local_point /= (collider_scale * collider_scale)
	local_point += Vector3(0.5, -0.5, 0) # X is about 0 to 1, Y is about 0 to -1.
	return local_point


func onpointing(newpointertarget, newpointertargetpoint):
	if newpointertarget != pointertarget:
		if is_instance_valid(pointertarget) and pointertarget == guipanel3d:
			guipanel3d.guipanelreleasemouse()
		
		if is_instance_valid(pointertarget) and pointertarget.has_method("set_materialoverride"):
			pointertarget.set_materialoverride(selectedhighlightmaterial if pointertarget == selectedtarget else null, pointertarget == selectedtarget)
			if pointertarget.scale.y != pointertargetscaley:
				sketchsystem.updateonepaths()

		pointertarget = newpointertarget
		if is_instance_valid(pointertarget):
			if pointertarget.has_method("set_materialoverride"):
				pointertarget.set_materialoverride(selectedpointerhighlightmaterial if pointertarget == selectedtarget else pointinghighlightmaterial, pointertarget == selectedtarget)
				LaserSpot.visible = false
				pointertargetscaley = pointertarget.scale.y
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
		guipanel3d.togglevisibility(controller.global_transform)
			
	if p_button == Buttons.VR_TRIGGER and is_instance_valid(pointertarget):
		print("clclc ", pointertarget.get_filename(), pointertarget.get_parent())
		if pointertarget.has_method("jump_up"):
			pointertarget.jump_up()
			
		elif pointertarget == guipanel3d:
			pass  #this is elsewhere processed

		elif pointertarget == drawnfloor:
			# drag node to new position on floor
			if controller.is_button_pressed(Buttons.VR_GRIP) and is_instance_valid(selectedtarget) and selectedtarget.has_method("set_materialoverride"):
				if pointertarget.getnodetype() == "ntPath":
					selectedtarget.global_transform.origin = pointertargetpoint
					sketchsystem.updateonepaths()
				gripbuttonpressused = true
				
			# new node on floor (connect from selected target)
			else:
				pointertarget = sketchsystem.newonepathnode(pointertargetpoint)
				if is_instance_valid(selectedtarget) and selectedtarget.has_method("set_materialoverride"):
					if selectedtarget.getnodetype() == "ntPath":
						pointertarget.scale.y = selectedtarget.scale.y
						sketchsystem.applyonepath(selectedtarget, pointertarget)
					selectedtarget.set_materialoverride(null, true)
				if controller.is_button_pressed(Buttons.VR_GRIP):
					selectedtarget = null
				else:
					selectedtarget = pointertarget
					selectedtarget.set_materialoverride(selectedpointerhighlightmaterial, true)
					
		# clear selected target by selecting again
		elif pointertarget == selectedtarget:
			if controller.is_button_pressed(Buttons.VR_GRIP):
				if selectedtarget.getnodetype() == "ntPath":
					sketchsystem.removeonepathnode(selectedtarget)
				gripbuttonpressused = true
			else:
				selectedtarget.set_materialoverride(pointinghighlightmaterial, true)
				if selectedtarget.getnodetype() == "ntStation":   # slight flaw in deselection where it can't tell reverting to highlight from selected
					var textpanel = sketchsystem.get_node("Centreline/TextPanel")
					textpanel.visible = false
			selectedtarget = null
			
		# click on new selected target (connect from previous selected target)
		else:
			if is_instance_valid(selectedtarget) and selectedtarget.has_method("set_materialoverride"):
				selectedtarget.set_materialoverride(null, true)
				if selectedtarget.getnodetype() == "ntPath" and pointertarget.getnodetype() == "ntPath":
					sketchsystem.applyonepath(selectedtarget, pointertarget)
			selectedtarget = pointertarget
			selectedtarget.set_materialoverride(selectedpointerhighlightmaterial, true)
				
	# change height of pointer target
	if p_button == Buttons.VR_PAD and is_instance_valid(pointertarget) and selectedtarget.has_method("set_materialoverride") and pointertarget.has_method("getnodetype") and pointertarget.getnodetype() == "ntPath":
		var left_right = controller.get_joystick_axis(0)
		var up_down = controller.get_joystick_axis(1)
		if abs(up_down) < 0.5 and abs(left_right) > 0.1:
			pointertarget.scale.y = max(0.1, pointertarget.scale.y + (1 if left_right > 0 else -1)*(1.0 if abs(left_right) < 0.8 else 0.1))

	if p_button == Buttons.VR_GRIP:
		gripbuttonpressused = false

func _on_button_release(p_button):
	# clear selection by squeezing and then releasing grip without doing anything in between
	if p_button == Buttons.VR_GRIP and not gripbuttonpressused and is_instance_valid(selectedtarget) and selectedtarget.has_method("set_materialoverride"):
		selectedtarget.set_materialoverride(pointinghighlightmaterial if selectedtarget == pointertarget else null, selectedtarget == pointertarget)
		selectedtarget = null

func _process(_delta):
	if !is_inside_tree():
		return
	if $Laser/RayCast.is_colliding():
		onpointing($Laser/RayCast.get_collider(), $Laser/RayCast.get_collision_point())
	else:
		onpointing(null, null)
	
