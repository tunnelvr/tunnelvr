extends Spatial

var planviewactive = false
var drawingtype = DRAWING_TYPE.DT_PLANVIEW
onready var ImageSystem = get_node("/root/Spatial/ImageSystem")

var buttonidxtoitem = { }
var tree = null
var imgregex = RegEx.new()
var listregex = RegEx.new()

func fetchbuttonpressed(item, column, idx):
	print("iii ", item, " ", column, "  ", idx)
	if item == null:
		print("fetchbuttonpressed item is null problem")
		item = buttonidxtoitem.get(idx)
	var url = item.get_tooltip(0)
	var name = item.get_text(0)
	print("url to fetch: ", url)
	if imgregex.search(name):
		var paperdrawing = get_node("/root/Spatial/SketchSystem").newXCuniquedrawingPaper(url, DRAWING_TYPE.DT_FLOORTEXTURE)
		var pt0 = $PlanView.global_transform.origin
		pt0.y = min($RealPlanCamera.global_transform.origin.y - 2, pt0.y + 20)
		paperdrawing.global_transform = Transform(Vector3(1,0,0), Vector3(0,0,-1), Vector3(0,1,0), pt0)
		paperdrawing.get_node("XCdrawingplane").scale = Vector3(10, 10, 1)
		#get_node("/root/Spatial/SketchSystem").sharexcdrawingovernetwork(paperdrawing)
		ImageSystem.fetchpaperdrawing(paperdrawing)
		
	else:
		item.set_button_disabled(column, idx, true)
		#item.erase_button(column, idx)
		#buttonidxtoitem.erase(idx)
		item.set_custom_bg_color(0, Color("#ff0099"))
		ImageSystem.fetchunrolltree(tree, item, item.get_tooltip(0))

func addsubitem(upperitem, name, url):
	var item = tree.create_item(upperitem)
	item.set_text(0, name)
	item.set_tooltip(0, url)
	var img = Image.new()
	img.load("res://guimaterials/installbuttonimg.png" if imgregex.search(name) else "res://guimaterials/fetchbuttonimg.png")
	var tex = ImageTexture.new()
	tex.create_from_image(img)
	var idx = item.get_button_count(0)
	item.add_button(0, tex, idx)
	buttonidxtoitem[idx] = item

func openlinklistpage(item, htmltext):
	item.clear_custom_bg_color(0)
	var dirurl = item.get_tooltip(0)
	if not dirurl.ends_with("/"):
		dirurl += "/"
	var tree = $PlanView/Viewport/PlanGUI/PlanViewControls/Tree
	for m in listregex.search_all(htmltext):
		var lk = m.get_string(1)
		if not lk.begins_with("."):
			addsubitem(item, lk, dirurl + lk)

func _ready():
	listregex.compile('<li><a href="([^"]*)">')
	imgregex.compile('(?i)\\.(png|jpg|jpeg)$')

	$RealPlanCamera.set_as_toplevel(true)
	var fplangui = $PlanView/ViewportFake.get_node_or_null("PlanGUI")
	if fplangui != null:
		$PlanView/ViewportFake.remove_child(fplangui)
		$PlanView/Viewport.add_child(fplangui)
	$PlanView/Viewport/PlanGUI/PlanViewControls/ZoomView/ButtonCentre.connect("pressed", self, "buttoncentre_pressed")
	tree = $PlanView/Viewport/PlanGUI/PlanViewControls/Tree
	tree.connect("button_pressed", self, "fetchbuttonpressed")
	set_process(false)
	var root = tree.create_item()
	root.set_text(0, "Root of tree")
	addsubitem(root, "Ireby", "http://cave-registry.org.uk/svn/NorthernEngland/ThreeCountiesArea/rawscans/Ireby/")

func toggleplanviewactive():
	planviewactive = not planviewactive
	$PlanView/ProjectionScreen/ImageFrame.mesh.surface_get_material(0).emission_enabled = planviewactive
	set_process(planviewactive)

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

func _process(delta):
	var viewslide = $PlanView/Viewport/PlanGUI/PlanViewControls/ViewSlide
	var joypos = Vector2((-1 if viewslide.get_node("ButtonSlideLeft").is_pressed() else 0) + (1 if viewslide.get_node("ButtonSlideRight").is_pressed() else 0), 
						 (-1 if viewslide.get_node("ButtonSlideDown").is_pressed() else 0) + (1 if viewslide.get_node("ButtonSlideUp").is_pressed() else 0))
	if joypos != Vector2(0, 0):
		var plancamera = $PlanView/Viewport/PlanGUI/Camera
		plancamera.translation += Vector3(joypos.x, 0, -joypos.y)*plancamera.size/2*delta

	var zoomview = $PlanView/Viewport/PlanGUI/PlanViewControls/ZoomView
	var bzoomin = zoomview.get_node("ButtonZoomIn").is_pressed()
	var bzoomout = zoomview.get_node("ButtonZoomOut").is_pressed()
	if bzoomin or bzoomout:
		var zoomfac = 1/(1 + 0.5*delta) if bzoomin else 1 + 0.5*delta
		$PlanView/Viewport/PlanGUI/Camera.size *= zoomfac
		$RealPlanCamera/RealCameraBox.scale = Vector3($PlanView/Viewport/PlanGUI/Camera.size, 1.0, $PlanView/Viewport/PlanGUI/Camera.size)
	
func buttoncentre_pressed():
	var headcam = get_node("/root/Spatial").playerMe.get_node("HeadCam")
	$PlanView/Viewport/PlanGUI/Camera.translation = Vector3(headcam.global_transform.origin.x, $PlanView/Viewport/PlanGUI/Camera.translation.y, headcam.global_transform.origin.z)

func checkplanviewinfront(handrightcontroller):
	var planviewsystem = self
	var collider_transform = planviewsystem.get_node("PlanView").global_transform
	return collider_transform.xform_inv(handrightcontroller.global_transform.origin).z > 0

var viewport_mousedown = false
var viewport_point = Vector2(0,0)
func processplanviewpointing(raycastcollisionpoint, controller_trigger):
	var planviewsystem = self
	var plancamera = planviewsystem.get_node("PlanView/Viewport/PlanGUI/Camera")
	var collider_transform = planviewsystem.get_node("PlanView").global_transform
	var shape_size = planviewsystem.get_node("PlanView/CollisionShape").shape.extents * 2
	var collider_scale = collider_transform.basis.get_scale()
	var local_point = collider_transform.xform_inv(raycastcollisionpoint)
	local_point /= (collider_scale * collider_scale)
	local_point /= shape_size
	local_point += Vector3(0.5, -0.5, 0) # X is about 0 to 1, Y is about 0 to -1.
	viewport_point = Vector2(local_point.x, -local_point.y) * $PlanView/Viewport.size

	var rectrel = viewport_point - $PlanView/Viewport/PlanGUI/PlanViewControls.rect_position
	if rectrel.x > 0 and rectrel.y > 0 and rectrel.x < $PlanView/Viewport/PlanGUI/PlanViewControls.rect_size.x and rectrel.y < $PlanView/Viewport/PlanGUI/PlanViewControls.rect_size.y:
		var event = InputEventMouseMotion.new()
		event.position = viewport_point
		$PlanView/Viewport.input(event)
		if controller_trigger != viewport_mousedown:
			viewport_mousedown = controller_trigger
			event = InputEventMouseButton.new()
			event.pressed = viewport_mousedown
			event.button_index = BUTTON_LEFT
			event.position = viewport_point
			print("vppv viewport_point ", viewport_point)
			$PlanView/Viewport.input(event)
	else:
		if viewport_mousedown:
			planviewguipanelreleasemouse()
		var laspt = plancamera.project_position(viewport_point, 0)
		planviewsystem.get_node("RealPlanCamera/LaserScope").global_transform.origin = laspt
		planviewsystem.get_node("RealPlanCamera/LaserScope").visible = true
		planviewsystem.get_node("RealPlanCamera/LaserScope/LaserOrient/RayCast").force_raycast_update()

func planviewguipanelreleasemouse():
	assert (viewport_mousedown)
	var event = InputEventMouseButton.new()
	event.button_index = 1
	event.position = viewport_point
	$PlanView/Viewport.input(event)
	viewport_mousedown = false

func updatecentrelinesizes():
	var sca = 1
	if Tglobal.centrelineonly:
		sca = $PlanView/Viewport/PlanGUI/Camera.size/70.0*2.5
	for xcdrawing in get_tree().get_nodes_in_group("gpcentrelinegeo"):
		for xcn in xcdrawing.get_node("XCnodes").get_children():
			xcn.get_node("StationLabel").get_surface_material(0).set_shader_param("vertex_scale", sca)
			xcn.get_node("CollisionShape").scale = Vector3(sca*2, sca*2, sca*2)
		xcdrawing.linewidth = 0.035*sca
		xcdrawing.updatexcpaths()



