extends Control


var thumbarearadius = 50
onready var planviewsystem = get_node("/root/Spatial/PlanViewSystem")

var fingerdown1pos = null
var plancameratranslation = Vector2(0,0)
var plancameraxvec = Vector3(0,0,0)
var plancamerayvec = Vector3(0,0,0)
var plancamerasize = Vector2(0,0)
var touchscreentype = false

func setupphoneoverlaysystem(ltouchscreentype):
	visible = true
	Tglobal.phoneoverlay = self

	$MenuButton.connect("pressed", self, "menubuttonpressed")
	$BackgroundCapture/CollisionShape2D.disabled = false
	$BackgroundCapture.connect("input_event", self, "backgroundmotioninput")
	get_node("/root").connect("size_changed", self, "setupoverlaycomponentpositions")
	setupoverlaycomponentpositions()

func setupoverlaycomponentpositions():
	var n = 16
	var screensize = get_node("/root").size
	thumbarearadius = min(screensize.x, screensize.y)/4.5
	var thumbareamargin = thumbarearadius/7
	var pts = [ ]
	for i in range(16):
		pts.push_back(Vector2(cos(deg2rad(360.0*i/n)), sin(deg2rad(360.0*i/n)))*thumbarearadius); 
	$ThumbLeft/TouchCircle.set_polygon(PoolVector2Array(pts))
	$ThumbLeft/ThumbCircle.set_polygon(PoolVector2Array(pts))
	$ThumbLeft.transform.origin = Vector2(thumbareamargin + thumbarearadius, screensize.y - thumbarearadius - thumbareamargin)
	
	$ThumbRight/TouchCircle.set_polygon(PoolVector2Array(pts))
	$ThumbRight/ThumbCircle.set_polygon(PoolVector2Array(pts))
	$ThumbRight.transform.origin = Vector2(screensize.x - thumbareamargin - thumbarearadius, screensize.y - thumbarearadius - thumbareamargin)
	
	$BackgroundCapture/CollisionShape2D.shape.extents = screensize/2
	$BackgroundCapture.position = screensize/2

	var thumgapsize = screensize.x - 4*thumbareamargin - 4*thumbarearadius

	var guipanel3dviewport = get_node("/root/Spatial/GuiSystem/GUIPanel3D/Viewport")
	var orgpanelsize = guipanel3dviewport.get_node("GUI").rect_size
	var panelscale = min(thumgapsize/orgpanelsize.x, (screensize.y-2*thumbareamargin/orgpanelsize.y))

	guipanel3dviewport.rect_scale = Vector2(panelscale, panelscale)
	guipanel3dviewport.rect_position = Vector2(screensize.x/2 - orgpanelsize.x*panelscale/2, screensize.y - orgpanelsize.y*panelscale - thumbareamargin)
	guipanel3dviewport.visible = false

	$MenuButton.rect_position = guipanel3dviewport.rect_position + Vector2(orgpanelsize.x*panelscale/2, orgpanelsize.y*panelscale) - $MenuButton.rect_size*max(1, panelscale)
	$MenuButton.rect_scale = Vector2(max(1, panelscale), max(1, panelscale))
	
	var planviewviewport = get_node("/root/Spatial/PlanViewSystem/PlanView/Viewport")
	var planviewviewcontrols = planviewviewport.get_node("PlanGUI/PlanViewControls")
	var planviewcontrolsscale = screensize.x/planviewviewcontrols.rect_size.x
	planviewviewport.rect_scale = Vector2(planviewcontrolsscale, planviewcontrolsscale)
	planviewviewport.rect_position = Vector2(0, 0)
	planviewviewcontrols.rect_position = Vector2(0, screensize.y/planviewcontrolsscale - planviewviewcontrols.rect_size.y)


func menubuttonpressed():
	var guipanel3dviewport = get_node("/root/Spatial/GuiSystem/GUIPanel3D/Viewport")
	if guipanel3dviewport.visible:
		get_node("/root/Spatial/GuiSystem/GUIPanel3D").setguipanelhide()
	else:
		get_node("/root/Spatial/GuiSystem/GUIPanel3D").setguipanelvisible(null)



var screentouchplaces = { }
func backgroundmotioninput(viewport: Object, event: InputEvent, shape_idx: int):
	if event is InputEventMouseButton:
		if touchscreentype or event.button_index != 1:
			return
		var ievent = event
		event = InputEventScreenTouch.new()
		event.pressed = ievent.pressed
		event.index = 0
		event.position = ievent.position
	if event is InputEventMouseMotion:
		if touchscreentype or (event.button_mask & 1) == 0:
			return
		var ievent = event
		event = InputEventScreenDrag.new()
		event.index = 0
		event.position = ievent.position

	if event is InputEventScreenTouch:
		if event.pressed:
			if (event.position - $ThumbLeft.position).length() <= thumbarearadius:
				screentouchplaces[event.index] = -1
				$ThumbLeft/ThumbCircle.visible = true
			elif $ThumbRight.input_pickable and (event.position - $ThumbRight.position).length() <= thumbarearadius:
				screentouchplaces[event.index] = 1
				$ThumbRight/ThumbCircle.visible = true
			elif planviewsystem.visible:
				screentouchplaces[event.index] = 0
				var plancamera = planviewsystem.get_node("PlanView/Viewport/PlanGUI/Camera")
				fingerdown1pos = event.position
				var fingerdown1posPP = plancamera.project_position(fingerdown1pos, 0.0)
				plancameraxvec = plancamera.project_position(fingerdown1pos+Vector2(1,0), 0.0) - fingerdown1posPP; 
				plancamerayvec = plancamera.project_position(fingerdown1pos+Vector2(0,1), 0.0) - fingerdown1posPP; 
				print("ppp ", plancameraxvec, plancamera.transform.basis.x)
				plancameratranslation = plancamera.translation
				plancamerasize = plancamera.size
			else:
				return

		else:
			if screentouchplaces.get(event.index) == -1:
				$ThumbLeft/ThumbCircle.visible = false
				Tglobal.phonethumbviewposition = null
			elif screentouchplaces.get(event.index) == 1:
				$ThumbRight/ThumbCircle.visible = false
				Tglobal.phonethumbmotionposition = null
			elif screentouchplaces.get(event.index) == 0:
				fingerdown1pos = null
			screentouchplaces.erase(event.index)
			return
			
			
	if event is InputEventScreenDrag or event is InputEventScreenTouch:
		if screentouchplaces.get(event.index) == -1:
			Tglobal.phonethumbviewposition = (event.position - $ThumbLeft.transform.origin)/thumbarearadius
			$ThumbLeft/ThumbCircle.transform.origin = Tglobal.phonethumbviewposition*thumbarearadius
		elif screentouchplaces.get(event.index) == 1:
			Tglobal.phonethumbmotionposition = (event.position - $ThumbRight.transform.origin)/thumbarearadius
			$ThumbRight/ThumbCircle.transform.origin = Tglobal.phonethumbmotionposition*thumbarearadius
		elif screentouchplaces.get(event.index) == 0:
			var planviewpositiondict = { }
			var plancamera = planviewsystem.get_node("PlanView/Viewport/PlanGUI/Camera")
			var panvec = fingerdown1pos - event.position
			planviewpositiondict["plancamerapos"] = plancameratranslation + plancameraxvec*panvec.x + plancamerayvec*panvec.y
			#var zoomfac = 1/(1 + 0.5*delta) if bzoomin else 1 + 0.5*delta
			#var plancamera = $PlanView/Viewport/PlanGUI/Camera
			#planviewpositiondict["plancamerasize"] = plancamera.size * zoomfac
			planviewsystem.sketchsystem.actsketchchange([{"planview":planviewpositiondict}])




