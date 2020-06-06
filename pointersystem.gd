extends Spatial

# this has a pointer sphere added JGT
# (and a lot of other hacking)

# variables set by the 
var drawnfloor = null
var sketchsystem = null
var guipanel3d = null

enum Buttons { VR_TRIGGER = 15, VR_PAD=14, VR_BUTTON_BY=1, VR_GRIP=2 }
onready var controller = get_parent()
export var distance = 10

# Need to replace this with proper solution once support for layer selection has been added 
export (int, FLAGS, "Layer 1", "Layer 2", "Layer 3", "Layer 4", "Layer 5", "Layer 6", "Layer 7", "Layer 8", "Layer 9", "Layer 10", "Layer 11", "Layer 12", "Layer 13", "Layer 14", "Layer 15", "Layer 16", "Layer 17", "Layer 18", "Layer 19", "Layer 20") var collision_mask = 15 

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

onready var ws = ARVRServer.world_scale

func set_collision_mask(p_new_mask):
	collision_mask = p_new_mask
	print("collision_maskcollision_maskcollision_mask ", collision_mask)
	if $Laser:
		$Laser/RayCast.collision_mask = collision_mask

func set_distance(p_new_value):
	distance = p_new_value
	print("distance", distance, p_new_value)
	print(LaserSquare, "sss", LaserSpot)
	if $Laser:
		$Laser.mesh.size.z = distance
		$Laser.translation.z = distance * -0.5
		$Laser/RayCast.translation.z = distance * 0.5
		$Laser/RayCast.cast_to.z = -distance

func _ready():
	get_parent().connect("button_pressed", self, "_on_button_pressed")
	get_parent().connect("button_release", self, "_on_button_release")
	print("LaserSquare ", LaserSquare)
	print("LaserSpot ", LaserSpot)
	pointinghighlightmaterial.albedo_color = Color(0.92, 0.49, 0.13, 1.0)
	pointinghighlightmaterial.flags_no_depth_test = true
	selectedhighlightmaterial.albedo_color = Color(0.92, 0.99, 0.13, 1.0)
	selectedpointerhighlightmaterial.albedo_color = Color(0.82, 0.99, 0.93, 1.0)
	selectedpointerhighlightmaterial.flags_no_depth_test = true
	
	# apply our world scale to our laser position
	$Laser.translation.y = laser_y * ws
	
	# init our state
	print("in the pointer onready")
	set_distance(distance)

func onpointing(newpointertarget, newpointertargetpoint):
	if newpointertarget != pointertarget:
		if is_instance_valid(pointertarget) and pointertarget.has_method("set_materialoverride"):
			pointertarget.set_materialoverride(selectedhighlightmaterial if pointertarget == selectedtarget else null)
			if pointertarget.scale.y != pointertargetscaley:
				sketchsystem.updateonepaths()

		pointertarget = newpointertarget
		if is_instance_valid(pointertarget):
			if pointertarget.has_method("set_materialoverride"):
				pointertarget.set_materialoverride(selectedpointerhighlightmaterial if pointertarget == selectedtarget else pointinghighlightmaterial)
				LaserSpot.visible = false
				pointertargetscaley = pointertarget.scale.y
			else:
				LaserSpot.visible = true
		else:
			LaserSpot.visible = false
	pointertargetpoint = newpointertargetpoint

	if LaserSpot.visible:
		LaserSpot.global_transform.origin = pointertargetpoint

			#LaserSquare.visible:
			#LaserSquare.global_transform.origin = newpointertargetpoint 
			


func _on_button_pressed(p_button):
	print("pppp ", pointertargetpoint)
	if p_button == Buttons.VR_BUTTON_BY:
		if not guipanel3d.visible:
			var pos = controller.global_transform.origin - 0.8*(controller.global_transform.basis.z)
			var trans = Transform(controller.global_transform)
			trans.origin = pos
			guipanel3d.global_transform = trans
			guipanel3d.visible = true
		else:
			guipanel3d.visible = false
			
	if p_button == Buttons.VR_TRIGGER and is_instance_valid(pointertarget):
		if pointertarget.has_method("jump_up"):
			pointertarget.jump_up()
			
		elif pointertarget == drawnfloor:
			# drag node to new position on floor
			if controller.is_button_pressed(Buttons.VR_GRIP) and is_instance_valid(selectedtarget) and selectedtarget.has_method("set_materialoverride"):
				selectedtarget.global_transform.origin = pointertargetpoint
				sketchsystem.updateonepaths()
				gripbuttonpressused = true
				
			# new node on floor (connect from selected target)
			else:
				pointertarget = sketchsystem.newonepathnode(pointertargetpoint)
				if is_instance_valid(selectedtarget) and selectedtarget.has_method("set_materialoverride"):
					pointertarget.scale.y = selectedtarget.scale.y
					sketchsystem.applyonepath(selectedtarget, pointertarget)
					selectedtarget.set_materialoverride(null)
				if controller.is_button_pressed(Buttons.VR_GRIP):
					selectedtarget = null
				else:
					selectedtarget = pointertarget
					selectedtarget.set_materialoverride(selectedpointerhighlightmaterial)
					
		# clear selected target by selecting again
		elif pointertarget == selectedtarget:
			if controller.is_button_pressed(Buttons.VR_GRIP):
				sketchsystem.removeonepathnode(selectedtarget)
				gripbuttonpressused = true
			else:
				selectedtarget.set_materialoverride(pointinghighlightmaterial)
			selectedtarget = null
			
		# click on new selected target (connect from previous selected target)
		else:
			if is_instance_valid(selectedtarget) and selectedtarget.has_method("set_materialoverride"):
				selectedtarget.set_materialoverride(null)
				sketchsystem.applyonepath(selectedtarget, pointertarget)
			selectedtarget = pointertarget
			selectedtarget.set_materialoverride(selectedpointerhighlightmaterial)
				
	# change height of pointer target
	if p_button == Buttons.VR_PAD and is_instance_valid(pointertarget):
		var left_right = controller.get_joystick_axis(0)
		var up_down = controller.get_joystick_axis(1)
		if abs(up_down) < 0.5 and abs(left_right) > 0.1:
			pointertarget.scale.y = max(0.1, pointertarget.scale.y + (1 if left_right > 0 else -1)*(1 if abs(left_right) < 0.8 else 0.1))

	if p_button == Buttons.VR_GRIP:
		gripbuttonpressused = false

func _on_button_release(p_button):
	# clear selection by squeezing and releasing grip
	if p_button == Buttons.VR_GRIP and not gripbuttonpressused and is_instance_valid(selectedtarget) and selectedtarget.has_method("set_materialoverride"):
		selectedtarget.set_materialoverride(pointinghighlightmaterial if selectedtarget == pointertarget else null)
		selectedtarget = null

func _process(delta):
	if !is_inside_tree():
		return
	var new_ws = ARVRServer.world_scale
	if (ws != new_ws):
		ws = new_ws
		$Laser.translation.y = laser_y * ws	
	
	if $Laser/RayCast.is_colliding():
		onpointing($Laser/RayCast.get_collider(), $Laser/RayCast.get_collision_point())
	else:
		onpointing(null, null)
	

# This should pop up the menu of options to do
func _on_ARVRController_Right_button_pressed(button):
	print("right button pressed", button)
	if button == Buttons.VR_BUTTON_BY:
		#sketchsystem.savesketchsystem()
		sketchsystem.loadsketchsystem()
