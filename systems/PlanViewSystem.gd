extends Spatial

var planviewactive = false
var drawingtype = DRAWING_TYPE.DT_PLANVIEW
onready var ImageSystem = get_node("/root/Spatial/ImageSystem")
var activetargetfloor = null
var activetargetfloortransformpos = null
var activetargetfloorimgtrim = null

var buttonidxtoitem = { }
var tree = null
var imgregex = RegEx.new()
var listregex = RegEx.new()

var installbuttontex = null
var imagebuttontex = null

func setactivetargetfloor(newactivetargetfloor, gripbuttonheld):
	if activetargetfloor != null:
		activetargetfloor.get_node("XCdrawingplane/CollisionShape/MeshInstance").get_surface_material(0).set_shader_param("albedo", Color("#FEF4D5"))
	if gripbuttonheld and activetargetfloor == newactivetargetfloor:
		activetargetfloor = null
	else:
		activetargetfloor = newactivetargetfloor
	if activetargetfloor != null:
		activetargetfloor.get_node("XCdrawingplane/CollisionShape/MeshInstance").get_surface_material(0).set_shader_param("albedo", Color("#DDFFCC"))

func fetchbuttonpressed(item, column, idx):
	var sketchsystem = get_node("/root/Spatial/SketchSystem")
	print("iii ", item, " ", column, "  ", idx)
	if item == null:
		print("fetchbuttonpressed item is null problem")
		item = buttonidxtoitem.get(idx)
	var url = item.get_tooltip(0)
	var name = item.get_text(0)
	print("url to fetch: ", url)
	if imgregex.search(name):
		var pt0 = $RealPlanCamera.global_transform.origin - Vector3(0,100,0)
		for xcdrawing in sketchsystem.get_node("XCdrawings").get_children():
			if xcdrawing.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE:
				var floory = xcdrawing.global_transform.origin.y
				if pt0.y <= floory:
					pt0.y = floory + 0.1
		var paperdrawing = sketchsystem.newXCuniquedrawingPaper(url, DRAWING_TYPE.DT_FLOORTEXTURE)
		#var pt0 = $PlanView.global_transform.origin
		paperdrawing.global_transform = Transform(Vector3(1,0,0), Vector3(0,0,-1), Vector3(0,1,0), pt0)
		paperdrawing.get_node("XCdrawingplane").scale = Vector3(10, 10, 1)
		#get_node("/root/Spatial/SketchSystem").sharexcdrawingovernetwork(paperdrawing)
		ImageSystem.fetchpaperdrawing(paperdrawing)
		setactivetargetfloor(paperdrawing, false)
		#activetargetfloorimgtrim = { "imgwidth":activetargetfloor.imgwidth, 
		#							 "imgtrimleftdown":activetargetfloor.imgtrimleftdown,
		#							 "imgtrimrightup":activetargetfloor.imgtrimrightup }
		# send to actsketchchange once it's here
		
	else:
		item.set_button_disabled(column, idx, true)
		#item.erase_button(column, idx)
		#buttonidxtoitem.erase(idx)
		item.set_custom_bg_color(0, Color("#ff0099"))
		ImageSystem.fetchunrolltree(tree, item, item.get_tooltip(0))

func addsubitem(upperitem, name, url):
	print("**** ", upperitem, name, url)
	var item = tree.create_item(upperitem)
	item.set_text(0, name)
	item.set_tooltip(0, url)
	var tex = installbuttontex if imgregex.search(name) else imagebuttontex
	#var idx = item.get_button_count(0)
	var idx = len(buttonidxtoitem)
	item.add_button(0, tex)
	print("Adding button ", idx, " for name ", name, " tex ", tex)
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
			lk = lk.replace("&amp;", "&")
			addsubitem(item, lk, dirurl + lk)

func _ready():
	listregex.compile('<li><a href="([^"]*)">')
	imgregex.compile('(?i)\\.(png|jpg|jpeg)$')

	var installbuttonimg = Image.new()
	installbuttonimg.load("res://guimaterials/installbuttonimg.png")
	installbuttontex = ImageTexture.new()
	installbuttontex.create_from_image(installbuttonimg)

	var imagebuttonimg = Image.new()
	imagebuttonimg.load("res://guimaterials/fetchbuttonimg.jpg")
	imagebuttontex = ImageTexture.new()
	imagebuttontex.create_from_image(imagebuttonimg)

	$RealPlanCamera.set_as_toplevel(true)
	var fplangui = $PlanView/ViewportFake.get_node_or_null("PlanGUI")
	if fplangui != null:
		$PlanView/ViewportFake.remove_child(fplangui)
		$PlanView/Viewport.add_child(fplangui)
	$PlanView/Viewport/PlanGUI/PlanViewControls/ZoomView/ButtonCentre.connect("pressed", self, "buttoncentre_pressed")
	call_deferred("readydeferred")
	
func readydeferred():
	print("readydeferredreadydeferredreadydeferred")
	tree = $PlanView/Viewport/PlanGUI/PlanViewControls/Tree
	tree.connect("button_pressed", self, "fetchbuttonpressed")
	var root = tree.create_item()
	root.set_text(0, "Root of treee")
	print("calling addsubitemaddsubitemaddsubitem")
	addsubitem(root, "Ireby", "http://cave-registry.org.uk/svn/NorthernEngland/ThreeCountiesArea/rawscans/Ireby/")
	
	#var tmpdir = "user://test.txt"
	var tmpfile = "user://test.txt"
	#			if not Directory.new().dir_exists(nonimagedir):
	#			var err = Directory.new().make_dir(nonimagedir)
	var tmpfileexists = File.new().file_exists(tmpfile)
	print("  tmpfileexists ", tmpfileexists)
	var fout = File.new()
	fout.open(tmpfile, File.WRITE)
	fout.store_line("Hi there")
	fout.close()
	var tmpfileexists1 = File.new().file_exists(tmpfile)
	print("  tmpfileexists1 ", tmpfileexists1)
	set_process(false)
	
	

func toggleplanviewactive():
	planviewactive = not planviewactive
	if planviewactive:
		$PlanView/ProjectionScreen/ImageFrame.mesh.surface_get_material(0).emission_enabled = true
		set_process(true)
	else:
		$PlanView/ProjectionScreen/ImageFrame.mesh.surface_get_material(0).emission_enabled = false
		set_process(false)
		setactivetargetfloor(null, false)

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

	if activetargetfloor != null and len(activetargetfloor.nodepoints) == 0:
		var floortrim = $PlanView/Viewport/PlanGUI/PlanViewControls/FloorTrim
		var joypostrimld = Vector2((-1 if floortrim.get_node("ButtonTrimLeftLeft").is_pressed() else 0) + (1 if floortrim.get_node("ButtonTrimLeftRight").is_pressed() else 0), 
								   (-1 if floortrim.get_node("ButtonTrimDownDown").is_pressed() else 0) + (1 if floortrim.get_node("ButtonTrimDownUp").is_pressed() else 0))
		var joypostrimru = Vector2((-1 if floortrim.get_node("ButtonTrimRightLeft").is_pressed() else 0) + (1 if floortrim.get_node("ButtonTrimRightRight").is_pressed() else 0), 
								   (-1 if floortrim.get_node("ButtonTrimUpDown").is_pressed() else 0) + (1 if floortrim.get_node("ButtonTrimUpUp").is_pressed() else 0))
		var floormove = $PlanView/Viewport/PlanGUI/PlanViewControls/FloorMove
		var joyposmove = Vector3((-1 if floormove.get_node("ButtonMoveLeft").is_pressed() else 0) + (1 if floormove.get_node("ButtonMoveRight").is_pressed() else 0), 
								 (-1 if floormove.get_node("ButtonMoveDown").is_pressed() else 0) + (1 if floormove.get_node("ButtonMoveUp").is_pressed() else 0), 
								 (-0.5 if floormove.get_node("ButtonMoveFall").is_pressed() else 0) + (0.5 if floormove.get_node("ButtonMoveRise").is_pressed() else 0))
		var joygrow = (-1 if floormove.get_node("ButtonShrink").is_pressed() else 0) + (1 if floormove.get_node("ButtonGrow").is_pressed() else 0)
		if joypostrimld != Vector2(0,0) or joypostrimru != Vector2(0,0) or joyposmove != Vector3(0,0,0) or joygrow != 0:
			var txcdata = { "name":activetargetfloor.get_name(), 
							"rpcoptional":1,
							"timestamp":OS.get_ticks_msec()*0.001 }
			var d = activetargetfloor
			var drawingplane = d.get_node("XCdrawingplane")
			var sfac = delta*8
			if joyposmove != Vector3(0,0,0):
				txcdata["prevtransformpos"] = d.transform
				txcdata["transformpos"] = Transform(d.transform.basis, d.transform.origin + d.transform.basis*joyposmove*delta*8)

			if joypostrimld != Vector2(0,0) or joypostrimru != Vector2(0,0) or joygrow != 0:
				txcdata["previmgtrim"] = { "imgwidth":d.imgwidth, "imgtrimleftdown":d.imgtrimleftdown, "imgtrimrightup":d.imgtrimrightup }
				var gfac = 1 + joygrow*delta*0.2
				var imgtrim = { "imgwidth":d.imgwidth*gfac, "imgtrimleftdown":d.imgtrimleftdown*gfac, "imgtrimrightup":d.imgtrimrightup*gfac }
				txcdata["imgtrim"] = imgtrim
				var imgheight = imgtrim["imgwidth"]*d.imgheightwidthratio
				imgtrim["imgtrimleftdown"] = Vector2(clamp(imgtrim["imgtrimleftdown"].x + joypostrimld.x*sfac, -imgtrim["imgwidth"]*0.5, imgtrim["imgtrimrightup"].x-0.1), 
													 clamp(imgtrim["imgtrimleftdown"].y + joypostrimld.y*sfac, -imgheight*0.5, imgtrim["imgtrimrightup"].y-0.1))
				imgtrim["imgtrimrightup"] = Vector2(clamp(imgtrim["imgtrimrightup"].x + joypostrimru.x*sfac, imgtrim["imgtrimleftdown"].x+0.1, imgtrim["imgwidth"]*0.5), 
													clamp(imgtrim["imgtrimrightup"].y + joypostrimru.y*sfac, imgtrim["imgtrimleftdown"].y+0.1, imgheight*0.5))
									
				#d.imgtrimleftdown = Vector2(clamp(d.imgtrimleftdown.x + joypostrimld.x*sfac, -d.imgwidth*0.5, d.imgtrimrightup.x-0.1), 
				#							clamp(d.imgtrimleftdown.y + joypostrimld.y*sfac, -imgheight*0.5, d.imgtrimrightup.y-0.1))
				#d.imgtrimrightup = Vector2(clamp(d.imgtrimrightup.x + joypostrimru.x*sfac, d.imgtrimleftdown.x+0.1, d.imgwidth*0.5), 
				#						   clamp(d.imgtrimrightup.y + joypostrimru.y*sfac, d.imgtrimleftdown.y+0.1, imgheight*0.5))
				# move these into the actsketchchange function
				#drawingplane.transform.origin = Vector3((d.imgtrimleftdown.x + d.imgtrimrightup.x)*0.5, (d.imgtrimleftdown.y + d.imgtrimrightup.y)*0.5, 0)
				#drawingplane.scale = Vector3((d.imgtrimrightup.x - d.imgtrimleftdown.x)*0.5, (d.imgtrimrightup.y - d.imgtrimleftdown.y)*0.5, 1)
				#var m = d.get_node("XCdrawingplane/CollisionShape/MeshInstance").get_surface_material(0)
				#m.set_shader_param("uv1_scale", Vector3((d.imgtrimrightup.x - d.imgtrimleftdown.x)/d.imgwidth, (d.imgtrimrightup.y - d.imgtrimleftdown.y)/imgheight, 1))
				#m.set_shader_param("uv1_offset", Vector3((d.imgtrimleftdown.x - (-d.imgwidth*0.5))/d.imgwidth, -(d.imgtrimrightup.y - (imgheight*0.5))/imgheight, 0))

			var sketchsystem = get_node("/root/Spatial/SketchSystem")
			sketchsystem.actsketchchange([txcdata])  # step through this and make the 


	
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
	var inguipanel = (rectrel.x > 0 and rectrel.y > 0 and rectrel.x < $PlanView/Viewport/PlanGUI/PlanViewControls.rect_size.x and rectrel.y < $PlanView/Viewport/PlanGUI/PlanViewControls.rect_size.y)
	if inguipanel:
		var event = InputEventMouseMotion.new()
		event.position = viewport_point
		$PlanView/Viewport.input(event)
		if controller_trigger != viewport_mousedown:
			viewport_mousedown = controller_trigger
			event = InputEventMouseButton.new()
			event.pressed = viewport_mousedown
			event.button_index = BUTTON_LEFT
			event.position = viewport_point
			$PlanView/Viewport.input(event)
	else:
		if viewport_mousedown:
			planviewguipanelreleasemouse()
		var laspt = plancamera.project_position(viewport_point, 0)
		planviewsystem.get_node("RealPlanCamera/LaserScope").global_transform.origin = laspt
		planviewsystem.get_node("RealPlanCamera/LaserScope").visible = true
		planviewsystem.get_node("RealPlanCamera/LaserScope/LaserOrient/RayCast").force_raycast_update()
	return inguipanel
	
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



