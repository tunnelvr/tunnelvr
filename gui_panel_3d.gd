extends StaticBody

onready var viewport: Viewport = get_child(0)
onready var collisionshape: CollisionShape = get_child(1)
onready var ARVRworld_scale = ARVRServer.world_scale

var viewport_point := Vector2(0, 0)
var viewport_mousedown := false


func _on_buttonload_pressed():
	get_node("../SketchSystem").loadsketchsystem()
	$Viewport/GUI/Panel/Label.text = "Sketch Loaded"
	
func _on_buttonsave_pressed():
	get_node("../SketchSystem").savesketchsystem()
	$Viewport/GUI/Panel/Label.text = "Sketch Saved"

func _on_buttonshowxs_toggled(button_pressed):
	get_node("../SketchSystem/Centreline/CentrelineCrossSections").visible = button_pressed
	$Viewport/GUI/Panel/Label.text = "XS shown" if button_pressed else "XS hidden"

func _on_buttonshiftfloor_pressed():
	get_node("../SketchSystem/Centreline").shiftfloorfromdrawnstations()
	$Viewport/GUI/Panel/Label.text = "Floor shifted"
	
func _ready():
	$Viewport/GUI/Panel/ButtonLoad.connect("pressed", self, "_on_buttonload_pressed")
	$Viewport/GUI/Panel/ButtonSave.connect("pressed", self, "_on_buttonsave_pressed")
	$Viewport/GUI/Panel/ButtonShowXS.connect("toggled", self, "_on_buttonshowxs_toggled")
	$Viewport/GUI/Panel/ButtonShiftFloor.connect("pressed", self, "_on_buttonshiftfloor_pressed")


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
	else:
		visible = false	
	
func guipanelsendmousemotion(collision_point, controller_global_transform, controller_trigger):
	var collider_transform = global_transform
	if collider_transform.xform_inv(controller_global_transform.origin).z < 0:
		return # Don't allow pressing if we're behind the GUI.
	
	# Convert the collision to a relative position. 
	var shape_size = collisionshape.shape.extents * 2
	var collider_scale = collider_transform.basis.get_scale()
	var local_point = collider_transform.xform_inv(collision_point)
	# this rescaling because of no xform_affine_inv.  https://github.com/godotengine/godot/issues/39433
	local_point /= (collider_scale * collider_scale)
	local_point /= shape_size
	local_point += Vector3(0.5, -0.5, 0) # X is about 0 to 1, Y is about 0 to -1.
	
	# Find the viewport position by scaling the relative position by the viewport size. Discard Z.
	viewport_point = Vector2(local_point.x, -local_point.y) * viewport.size
	
	# Send mouse motion to the GUI.
	var event = InputEventMouseMotion.new()
	event.position = viewport_point
	viewport.input(event)
	
	# Figure out whether or not we should trigger a click.
	var new_viewport_mousedown := false
	var distance = controller_global_transform.origin.distance_to(collision_point) / ARVRworld_scale
	if distance < 0.1:
		new_viewport_mousedown = true # Allow "touching" the GUI.
	else:
		new_viewport_mousedown = controller_trigger
	
	# Send a left click to the GUI depending on the above.
	if new_viewport_mousedown != viewport_mousedown:
		event = InputEventMouseButton.new()
		event.pressed = new_viewport_mousedown
		event.button_index = BUTTON_LEFT
		event.position = viewport_point
		viewport.input(event)
		viewport_mousedown = new_viewport_mousedown

func guipanelreleasemouse():
	if viewport_mousedown:
		var event = InputEventMouseButton.new()
		event.button_index = 1
		event.position = viewport_point
		viewport.input(event)
		viewport_mousedown = false
		
