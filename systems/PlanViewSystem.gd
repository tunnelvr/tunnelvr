extends Spatial

var planviewactive = false
var drawingtype = DRAWING_TYPE.DT_PLANVIEW

func _ready():
	$RealPlanCamera.set_as_toplevel(true)

func toggleplanviewactive():
	planviewactive = not planviewactive
	$PlanView/ProjectionScreen/ImageFrame.mesh.surface_get_material(0).emission_enabled = planviewactive

func setplanviewvisible(planviewvisible, guidpaneltransform, guidpanelsize):
	if planviewvisible:
		var paneltrans = $PlanView.global_transform
		paneltrans.origin = guidpaneltransform.origin + guidpaneltransform.basis.y*(guidpanelsize.y/2) + Vector3(0,$PlanView/ProjectionScreen/ImageFrame.mesh.size.y/2,0)
		var eyepos = get_node("/root/Spatial").playerMe.get_node("HeadCam").global_transform.origin
		paneltrans = paneltrans.looking_at(eyepos + 2*(paneltrans.origin-eyepos), Vector3(0, 1, 0))
		$PlanView.global_transform = paneltrans
		visible = true
		$PlanView/CollisionShape.disabled = false
	else:
		visible = false	
		$PlanView/CollisionShape.disabled = true

	
func processplanviewsliding(handright, _delta):
	var planviewsystem = self
	var joypos = Vector2(handright.get_joystick_axis(0) if handright.get_is_active() else 0.0, handright.get_joystick_axis(1) if handright.get_is_active() else 0.0)
	var plancamera = planviewsystem.get_node("PlanView/Viewport/Camera")
	if joypos.length() > 0.1 and not handright.is_button_pressed(BUTTONS.VR_GRIP):
		plancamera.translation += Vector3(joypos.x, 0, -joypos.y)*plancamera.size/2*_delta

func checkplanviewinfront(handright):
	var planviewsystem = self
	var collider_transform = planviewsystem.get_node("PlanView").global_transform
	return collider_transform.xform_inv(handright.global_transform.origin).z > 0

func processplanviewpointing(raycastcollisionpoint):
	var planviewsystem = self
	var plancamera = planviewsystem.get_node("PlanView/Viewport/Camera")
	var collider_transform = planviewsystem.get_node("PlanView").global_transform
	var shape_size = planviewsystem.get_node("PlanView/CollisionShape").shape.extents * 2
	var collider_scale = collider_transform.basis.get_scale()
	var local_point = collider_transform.xform_inv(raycastcollisionpoint)
	local_point /= (collider_scale * collider_scale)
	local_point /= shape_size
	local_point += Vector3(0.5, -0.5, 0) # X is about 0 to 1, Y is about 0 to -1.
	var viewport_point = Vector2(local_point.x, -local_point.y) * planviewsystem.get_node("PlanView/Viewport").size
	var laspt = plancamera.project_position(viewport_point, 0)
	planviewsystem.get_node("RealPlanCamera/LaserScope").global_transform.origin = laspt
	#print("pp ", laspt)
	
	planviewsystem.get_node("RealPlanCamera/LaserScope").visible = true
	planviewsystem.get_node("RealPlanCamera/LaserScope/RayCast").force_raycast_update()

func updatecentrelinesizes():
	for xcdrawing in get_tree().get_nodes_in_group("gpcentrelinegeo"):
		print(xcdrawing.get_name())
