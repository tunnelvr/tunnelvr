extends Control


var thumbarearadius = 50
onready var planviewsystem = get_node("/root/Spatial/PlanViewSystem")

var plancamerascreensize = Vector2(100,100)
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
	plancamerascreensize = get_node("/root").size
	thumbarearadius = min(plancamerascreensize.x, plancamerascreensize.y)/4.5
	var thumbareamargin = thumbarearadius/7
	var pts = [ ]
	for i in range(16):
		pts.push_back(Vector2(cos(deg2rad(360.0*i/n)), sin(deg2rad(360.0*i/n)))*thumbarearadius); 
	var ptsrect = [ Vector2(thumbarearadius,thumbarearadius), Vector2(thumbarearadius,-thumbarearadius), Vector2(-thumbarearadius,-thumbarearadius), Vector2(-thumbarearadius,thumbarearadius) ]
	$ThumbLeft/TouchCircle.set_polygon(PoolVector2Array(ptsrect))
	$ThumbLeft/ThumbCircle.set_polygon(PoolVector2Array(pts))
	$ThumbLeft.transform.origin = Vector2(thumbareamargin + thumbarearadius, plancamerascreensize.y - thumbarearadius - thumbareamargin)
	
	$ThumbRight/TouchCircle.set_polygon(PoolVector2Array(pts))
	$ThumbRight/ThumbCircle.set_polygon(PoolVector2Array(pts))
	$ThumbRight.transform.origin = Vector2(plancamerascreensize.x - thumbareamargin - thumbarearadius, plancamerascreensize.y - thumbarearadius - thumbareamargin)
	
	$BackgroundCapture/CollisionShape2D.shape.extents = plancamerascreensize/2
	$BackgroundCapture.position = plancamerascreensize/2

	var thumgapsize = plancamerascreensize.x - 4*thumbareamargin - 4*thumbarearadius

	var guipanel3dviewport = get_node("/root/Spatial/GuiSystem/GUIPanel3D/Viewport")
	var orgpanelsize = guipanel3dviewport.get_node("GUI").rect_size
	var panelscale = min(thumgapsize/orgpanelsize.x, (plancamerascreensize.y-2*thumbareamargin/orgpanelsize.y))

	guipanel3dviewport.rect_scale = Vector2(panelscale, panelscale)
	guipanel3dviewport.rect_position = Vector2(plancamerascreensize.x/2 - orgpanelsize.x*panelscale/2, plancamerascreensize.y - orgpanelsize.y*panelscale - thumbareamargin)
	guipanel3dviewport.visible = false

	$MenuButton.rect_position = guipanel3dviewport.rect_position + Vector2(orgpanelsize.x*panelscale/2, orgpanelsize.y*panelscale) - $MenuButton.rect_size*max(1, panelscale)
	$MenuButton.rect_scale = Vector2(max(1.5, panelscale), max(1.5, panelscale))
	
	var planviewviewport = get_node("/root/Spatial/PlanViewSystem/PlanView/Viewport")
	var planviewviewcontrols = planviewviewport.get_node("PlanGUI/PlanViewControls")
	var planviewcontrolsscale = plancamerascreensize.x/planviewviewcontrols.rect_size.x
	planviewviewport.rect_scale = Vector2(planviewcontrolsscale, planviewcontrolsscale)
	planviewviewport.rect_position = Vector2(0, 0)
	planviewviewcontrols.rect_position = Vector2(0, plancamerascreensize.y/planviewcontrolsscale - planviewviewcontrols.rect_size.y)


func menubuttonpressed():
	var guipanel3dviewport = get_node("/root/Spatial/GuiSystem/GUIPanel3D/Viewport")
	if guipanel3dviewport.visible:
		get_node("/root/Spatial/GuiSystem/GUIPanel3D").setguipanelhide()
	else:
		get_node("/root/Spatial/GuiSystem/GUIPanel3D").setguipanelvisible(null) 


var fingerdragpos = null
var fingerdragangle = 0.0
var fingerdraglength = 1.0
var plancameratranslation = Vector2(0,0)
var plancameraroty = 0.0
var plancameraxvec = Vector3(0,0,0)
var plancamerayvec = Vector3(0,0,0)
var plancamerazvec = Vector3(0,0,0)
var plancamerasize = 1.0

var screentouchplaces = { }
var screentouchplaces0pos = { }
func updatescreentouchplaces0state():
	if len(screentouchplaces0pos) == 0:
		fingerdragpos = null
		return
	var plancamera = planviewsystem.get_node("PlanView/Viewport/PlanGUI/Camera")
	var screentouchplaces0kpos = screentouchplaces0pos.values()
	if len(screentouchplaces0kpos) == 1:
		fingerdragpos = screentouchplaces0kpos[0]
	else:
		fingerdragpos = (screentouchplaces0kpos[0] + screentouchplaces0kpos[1])*0.5
		var fingerdragvec = screentouchplaces0kpos[1] - screentouchplaces0kpos[0]
		fingerdragangle = rad2deg(fingerdragvec.angle())
		fingerdraglength = fingerdragvec.length()
	var fingerdown1posPP = plancamera.project_position(fingerdragpos, 0.0)
	plancameraxvec = plancamera.project_position(fingerdragpos+Vector2(1,0), 0.0) - fingerdown1posPP; 
	plancamerayvec = plancamera.project_position(fingerdragpos+Vector2(0,1), 0.0) - fingerdown1posPP; 
	plancamerazvec = plancameraxvec.length()*(plancamera.project_position(fingerdragpos, 1.0) - fingerdown1posPP)
	plancameratranslation = plancamera.translation
	plancameraroty = plancamera.rotation_degrees.y
	plancamerasize = plancamera.size

func updatescreentouchplaces0drag():
	var plancamera = planviewsystem.get_node("PlanView/Viewport/PlanGUI/Camera")
	var planviewpositiondict = { }
	var screentouchplaces0kpos = screentouchplaces0pos.values()
	if len(screentouchplaces0kpos) == 1:
		var panvec = fingerdragpos - screentouchplaces0kpos[0]
		planviewpositiondict["plancamerapos"] = plancameratranslation + plancameraxvec*panvec.x + plancamerayvec*panvec.y
	else:
		var fingerdragposN = (screentouchplaces0kpos[0] + screentouchplaces0kpos[1])*0.5
		var fingerdragvecN = screentouchplaces0kpos[1] - screentouchplaces0kpos[0]
		var fingerdragangleN = rad2deg(fingerdragvecN.angle())
		var fingerdraglengthN = fingerdragvecN.length()
		var fingerdragangleNdiff = fingerdragangleN - fingerdragangle
		var croty = plancameraroty + fingerdragangleNdiff
		planviewpositiondict["plancamerarotation"] = Vector3(plancamera.rotation_degrees.x, croty, plancamera.rotation_degrees.z)
		var sizefac = fingerdraglength/fingerdraglengthN
		planviewpositiondict["plancamerasize"] = plancamerasize*sizefac
		var panvec = fingerdragpos - fingerdragposN
		var panvecdepthchange = 0.0
		if plancamera.rotation_degrees.x == 0.0:
			var veccenN = Vector2(fingerdragposN.x - plancamerascreensize.x/2, -planviewsystem.elevcameradist/plancameraxvec.length())
			var veccenNrot = veccenN*cos(deg2rad(fingerdragangleNdiff)) + Vector2(veccenN.y, -veccenN.x)*sin(deg2rad(fingerdragangleNdiff)) 
			panvec += Vector2(veccenN.x - veccenNrot.x, 0.0)
			panvecdepthchange = veccenNrot.y - veccenN.y
		else:
			var veccenN = fingerdragposN - plancamerascreensize/2
			var veccenNrot = veccenN*cos(deg2rad(fingerdragangleNdiff)) + Vector2(veccenN.y, -veccenN.x)*sin(deg2rad(fingerdragangleNdiff)) 
			panvec += veccenN - veccenNrot
		planviewpositiondict["plancamerapos"] = plancameratranslation + plancameraxvec*panvec.x + plancamerayvec*panvec.y + plancamerazvec*panvecdepthchange 
	planviewsystem.actplanviewdict(planviewpositiondict)


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
			if $ThumbLeft.visible and abs(event.position.x - $ThumbLeft.position.x) <= thumbarearadius and abs(event.position.y - $ThumbLeft.position.y) <= thumbarearadius:
				screentouchplaces[event.index] = -1
				$ThumbLeft/ThumbCircle.visible = true
			elif $ThumbRight.visible and (event.position - $ThumbRight.position).length() <= thumbarearadius:
				screentouchplaces[event.index] = 1
				$ThumbRight/ThumbCircle.visible = true
			elif planviewsystem.visible:
				screentouchplaces[event.index] = 0
				screentouchplaces0pos[event.index] = event.position
				updatescreentouchplaces0state()
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
				screentouchplaces0pos.erase(event.index)
				updatescreentouchplaces0state()
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
			screentouchplaces0pos[event.index] = event.position
			updatescreentouchplaces0drag()


