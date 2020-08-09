extends StaticBody

onready var ARVRworld_scale = ARVRServer.world_scale

var viewport_point := Vector2(0, 0)
var viewport_mousedown := false
onready var sketchsystem = get_node("/root/Spatial/SketchSystem")

func _on_buttonload_pressed():
	get_node("../pointersystem").setselectedtarget(null)
	sketchsystem.loadsketchsystem()
	$Viewport/GUI/Panel/Label.text = "Sketch Loaded"
	
func _on_buttonsave_pressed():
	sketchsystem.savesketchsystem()
	$Viewport/GUI/Panel/Label.text = "Sketch Saved"

func _on_buttonshowxs_toggled(button_pressed):
	sketchsystem.get_node("Centreline/CentrelineCrossSections").visible = button_pressed
	$Viewport/GUI/Panel/Label.text = "XS shown" if button_pressed else "XS hidden"

func _on_buttonheadtorch_toggled(button_pressed):
	get_parent().setheadtorchlight(button_pressed)
	$Viewport/GUI/Panel/Label.text = "Headtorch on" if button_pressed else "Headtorch off"

func _on_buttondoppelganger_toggled(button_pressed):
	get_parent().setdoppelganger(button_pressed)
	$Viewport/GUI/Panel/Label.text = "Doppelganger on" if button_pressed else "Doppelganger off"


func _on_buttonupdateshell_toggled(button_pressed):
	sketchsystem.updateworkingshell(button_pressed)
	$Viewport/GUI/Panel/Label.text = "UpdateShell shown" if button_pressed else "Shell hidden"

func _on_buttonshiftfloor_pressed():
	sketchsystem.get_node("Centreline").shiftfloorfromdrawnstations()
	$Viewport/GUI/Panel/Label.text = "Floor shifted"
	
func _ready():
	$Viewport/GUI/Panel/ButtonLoad.connect("pressed", self, "_on_buttonload_pressed")
	$Viewport/GUI/Panel/ButtonSave.connect("pressed", self, "_on_buttonsave_pressed")
	$Viewport/GUI/Panel/ButtonShowXS.connect("toggled", self, "_on_buttonshowxs_toggled")
	$Viewport/GUI/Panel/ButtonShiftFloor.connect("pressed", self, "_on_buttonshiftfloor_pressed")
	$Viewport/GUI/Panel/ButtonHeadtorch.connect("toggled", self, "_on_buttonheadtorch_toggled")
	$Viewport/GUI/Panel/ButtonDoppelganger.connect("toggled", self, "_on_buttondoppelganger_toggled")
	$Viewport/GUI/Panel/ButtonUpdateShell.connect("toggled", self, "_on_buttonupdateshell_toggled")

func clickbuttonheadtorch():
	$Viewport/GUI/Panel/ButtonHeadtorch.pressed = not $Viewport/GUI/Panel/ButtonHeadtorch.pressed
	_on_buttonheadtorch_toggled($Viewport/GUI/Panel/ButtonHeadtorch.pressed)

func togglevisibility(controller_global_transform):
	if not visible:
		var paneltrans = global_transform
		var controllertrans = controller_global_transform
		paneltrans.origin = controllertrans.origin - 0.8*ARVRworld_scale*(controllertrans.basis.z)
		var lookatpos = controllertrans.origin - 1.6*ARVRworld_scale*(controllertrans.basis.z)
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
	var distance = controller_global_transform.origin.distance_to(collision_point) / ARVRworld_scale
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
		
