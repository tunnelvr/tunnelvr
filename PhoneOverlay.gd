extends Control


var thumbarearadius = 50
onready var planviewsystem = get_node("/root/Spatial/PlanViewSystem")
onready var selfSpatial = get_node("/root/Spatial")
onready var pointersystem = get_node("/root/Spatial/Players/PlayerMe/pointersystem")

var plancamerascreensize = Vector2(100,100)
var touchscreentype = false

func _ready():
	$DrawmodeButton.connect("toggled", self, "_ondrawmodebuttontoggled")
	_ondrawmodebuttontoggled(false)
	planviewsystem.planviewcontrols.get_node("CentrelineActivity/DelLast").connect("pressed", self, "drawndeletelast")

func _ondrawmodebuttontoggled(button_pressed: bool):
	planviewsystem.planviewcontrols.get_node("CentrelineActivity").visible = button_pressed

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
	$DepthInfo.rect_scale = Vector2(max(1.5, panelscale), max(1.5, panelscale))
	$SelectmodeButton.rect_scale = Vector2(max(1.5, panelscale), max(1.5, panelscale))
	$DrawmodeButton.rect_scale = Vector2(max(1.5, panelscale), max(1.5, panelscale))
	$DrawmodeButton.rect_position = Vector2(0, plancamerascreensize.y/2 - $DrawmodeButton.rect_size.y/2*$DrawmodeButton.rect_scale.y)
	$SelectmodeButton.rect_position = $DrawmodeButton.rect_position - Vector2(0, $SelectmodeButton.rect_size.y*$SelectmodeButton.rect_scale.y)

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
var finger3vector = Vector2(0, 0)
var finger3a0 = 0.0
var finger3a1 = 0.0
var finger3a2 = 0.0
var finger3elevdist = 0.0
var finger3camerafar = 0.0

var screentouchplaces = { }
var screentouchplaces0pos = { }
var screentouchposindex0 = 0
var screentouchposindex1 = 0
var screentouchposindex2 = 0

var touchedindrawmode = false
var touchedinselectmode = false
var screentouchposindex0draw = -1

func setpointersystemray(drawpos):
	var headcam = planviewsystem.plancamera if planviewsystem.visible else selfSpatial.playerMe.get_node("HeadCam")
	var raycameranormal = headcam.project_ray_normal(drawpos)
	var rayorigin = headcam.project_ray_origin(drawpos)
	var upvec = Vector3(0,0,-1) if is_zero_approx(raycameranormal.x) and is_zero_approx(raycameranormal.z) else Vector3(0,1,0)
	var raytransform = Transform(Basis(), rayorigin).looking_at(rayorigin + raycameranormal*10, upvec)
	pointersystem.handright.pointerposearvrorigin = selfSpatial.playerMe.global_transform.inverse()*raytransform

func getactivecentreline():
	var centrelinename = planviewsystem.activecentrelinexcname
	if centrelinename:
		for lxcdrawingcentreline in get_tree().get_nodes_in_group("gpcentrelinegeo"):
			if centrelinename and centrelinename == lxcdrawingcentreline.get_name():
				return lxcdrawingcentreline
	return null

func makeactxcdrawndata(tpts, linetype):
	var headcam = planviewsystem.plancamera if planviewsystem.visible else selfSpatial.playerMe.get_node("HeadCam")
	var drawingcentreline = getactivecentreline()
	if drawingcentreline == null:
		return
	var cpts = [ ]
	for pt in tpts:
		var cpt = headcam.project_ray_origin(pt)
		var cnorm = headcam.project_ray_normal(pt)
		var cptP = cpt + cnorm*5
		cpts.push_back(drawingcentreline.transform.xform_inv(cptP))
	var drawingnodename0 = drawingcentreline.newuniquexcnodename("_")
	var drawingnodename1 = drawingcentreline.newuniquexcnodename("_")
	var xcdata = { "name":drawingcentreline.get_name(), 
				   "prevnodepoints":{ }, 
				   "nextnodepoints":{ drawingnodename0:cpts[0], drawingnodename1:cpts[-1] } 
				 }

	var intermediatenodes = Polynets.intermediatedrawnpoints(cpts, drawingcentreline.transform.basis)
	var xctdata = { "tubename":"**notset", 
					"xcname0":xcdata["name"],
					"xcname1":xcdata["name"],
					"prevdrawinglinks":[ ],
					"newdrawinglinks":[ drawingnodename0, drawingnodename1, linetype, intermediatenodes ] 
				  }
	planviewsystem.sketchsystem.setnewtubename(xctdata)
	planviewsystem.sketchsystem.actsketchchange([xcdata, xctdata])

const rN = 4
func unusednodepoints(drawingcentreline, prevdrawinglinks):
	var nE = int(len(prevdrawinglinks)/rN)
	var nodesconnectedset = { }
	for i in drawingcentreline.onepathpairs:
		nodesconnectedset[i] = 1
	var prevnodepoints = { }
	for iA in range(nE):
		var drawingnodename0 = prevdrawinglinks[iA*rN+0]
		var drawingnodename1 = prevdrawinglinks[iA*rN+1]
		if not nodesconnectedset.has(drawingnodename0):
			prevnodepoints[drawingnodename0] = drawingcentreline.nodepoints[drawingnodename0]
		if not nodesconnectedset.has(drawingnodename1):
			prevnodepoints[drawingnodename1] = drawingcentreline.nodepoints[drawingnodename1]
	return prevnodepoints


func drawndeletelast():
	var drawingcentreline = getactivecentreline()
	if drawingcentreline:
		var xctube = planviewsystem.sketchsystem.findxctube(drawingcentreline.name, drawingcentreline.name)
		if xctube != null and len(xctube.xcdrawinglink) != 0:
			var prevdrawinglinks = [ xctube.xcdrawinglink[-2], 
									 xctube.xcdrawinglink[-1], 
									 xctube.xcsectormaterials[-1], 
									 xctube.xclinkintermediatenodes[-1] if xctube.xclinkintermediatenodes else null ]
			var xctdata = { "tubename":xctube.get_name(), 
							"xcname0":drawingcentreline.get_name(),
							"xcname1":drawingcentreline.get_name(),
							"prevdrawinglinks":prevdrawinglinks,
							"newdrawinglinks":[ ] 
						  }
			var prevnodepoints = unusednodepoints(drawingcentreline, prevdrawinglinks)
			var xcdata = { "name":drawingcentreline.get_name(), 
						   "prevnodepoints":prevnodepoints, 
						   "nextnodepoints":{ } 
						 }
			planviewsystem.sketchsystem.actsketchchange([xctdata, xcdata])
	
	

func makeactxcdeletedata(tpts):
	print("delete here")
	
var drawcurvepoints = [ ]
func updatescreentouchplaces0stateDraw(pressed):
	var screentouchplaces0keys = screentouchplaces0pos.keys()
	if pressed and len(screentouchplaces0keys) == 1:
		screentouchposindex0draw = screentouchplaces0keys[0]
		if not touchedinselectmode and touchedindrawmode:
			$DrawCurve.visible = true
			drawcurvepoints = [ screentouchplaces0pos[screentouchposindex0draw] ]
			$DrawCurve.points = PoolVector2Array(drawcurvepoints)
		else:
			setpointersystemray(screentouchplaces0pos[screentouchposindex0draw])
			pointersystem.handright.pointervalid = true
			yield(get_tree(), "idle_frame")
			yield(get_tree(), "idle_frame")
			pointersystem._on_button_pressed(BUTTONS.VR_GRIP if touchedindrawmode else BUTTONS.VR_TRIGGER)
	elif not pressed and not screentouchplaces0pos.has(screentouchposindex0draw): 
		if $DrawCurve.visible:
			var tpts = Polynets.thincurve(drawcurvepoints, 2.0)
			$DrawCurve.points = PoolVector2Array(tpts)
			var linetypeoptions = planviewsystem.planviewcontrols.get_node("CentrelineActivity/LineType")
			var linetype = linetypeoptions.get_item_text(linetypeoptions.selected)
			if linetype == "*delete":
				makeactxcdeletedata(tpts)
			else:
				makeactxcdrawndata(tpts, linetype)
			$DrawCurve.visible = false
			print("drawcurve point count ", len(drawcurvepoints), " thinned to ", len($DrawCurve.points))
			
		else:
			pointersystem._on_button_release(BUTTONS.VR_GRIP if touchedindrawmode else BUTTONS.VR_TRIGGER)
			pointersystem.handright.pointervalid = false
		screentouchposindex0draw = -1
		
func updatescreentouchplaces0dragDraw():
	if screentouchposindex0draw != -1 and screentouchplaces0pos.has(screentouchposindex0draw):
		if $DrawCurve.visible:
			var pt = screentouchplaces0pos[screentouchposindex0draw]
			drawcurvepoints.push_back(pt)
			$DrawCurve.points = PoolVector2Array(drawcurvepoints)
		setpointersystemray(screentouchplaces0pos[screentouchposindex0draw])

func updatescreentouchplaces0state(pressed):
	if len(screentouchplaces0pos) == 0:
		fingerdragpos = null
		return
	var plancamera = planviewsystem.plancamera
	var screentouchplaces0keys = screentouchplaces0pos.keys()
	if not planviewsystem.visible:
		return
	if len(screentouchplaces0pos) == 1:
		screentouchposindex0 = screentouchplaces0keys[0]
		fingerdragpos = screentouchplaces0pos[screentouchposindex0]
	elif len(screentouchplaces0pos) == 2:
		screentouchposindex0 = screentouchplaces0keys[0]
		screentouchposindex1 = screentouchplaces0keys[1]
		var screentouchplaces0kpos0 = screentouchplaces0pos[screentouchposindex0]
		var screentouchplaces0kpos1 = screentouchplaces0pos[screentouchposindex1]
		fingerdragpos = (screentouchplaces0kpos0 + screentouchplaces0kpos1)*0.5
		var fingerdragvec = screentouchplaces0kpos1 - screentouchplaces0kpos0
		fingerdragangle = rad2deg(fingerdragvec.angle())
		fingerdraglength = fingerdragvec.length()
	elif len(screentouchplaces0pos) == 3:
		var sk = screentouchplaces0keys
		var sp = screentouchplaces0pos
		var sum3 = sp[sk[0]] + sp[sk[1]] + sp[sk[2]]
		var md = [ Vector2(((sp[sk[1]] + sp[sk[2]])/2 - sp[sk[0]]).length(), 0), Vector2(((sp[sk[0]] + sp[sk[2]])/2 - sp[sk[1]]).length(), 1), Vector2(((sp[sk[0]] + sp[sk[1]])/2 - sp[sk[2]]).length(), 2) ]
		md.sort()
		var mk = int(md[0][1])
		var p1 = sp[sk[mk]]
		var mk0 = (0 if mk != 0 else 1)
		var p0 = sp[sk[mk0]]
		if (p0.x - p1.x) - (p0.y - p1.y) > 0:
			mk0 = 3 - mk - mk0
		var mk2 = 3 - mk - mk0
		screentouchposindex0 = screentouchplaces0keys[mk0]
		screentouchposindex1 = screentouchplaces0keys[mk]
		screentouchposindex2 = screentouchplaces0keys[mk2]
		if plancamera.rotation_degrees.x == 0.0:
			$DepthInfo/Fields.text = "::Elev: %.2f, Far: %.2f" % [ planviewsystem.elevcameradist, plancamera.far ]
		else:
			$DepthInfo/Fields.text = "::Zhi: %.2f, Zlo: %.2f, Mid: %.2f" % [ plancamera.transform.origin.y, plancamera.transform.origin.y - plancamera.far, plancamera.transform.origin.y - planviewsystem.elevcameradist ]
		var screentouchplaces0kpos0 = screentouchplaces0pos[screentouchposindex0]
		var screentouchplaces0kpos1 = screentouchplaces0pos[screentouchposindex1]
		var screentouchplaces0kpos2 = screentouchplaces0pos[screentouchposindex2]
		finger3vector = (screentouchplaces0kpos2 - screentouchplaces0kpos0).normalized()
		finger3a0 = finger3vector.dot(screentouchplaces0kpos0)
		finger3a1 = finger3vector.dot(screentouchplaces0kpos1)
		finger3a2 = finger3vector.dot(screentouchplaces0kpos2)
		finger3elevdist = planviewsystem.elevcameradist
		finger3camerafar = plancamera.far
		print(" %.3f %.3f %.3f" % [finger3a0, finger3a1, finger3a2], finger3vector)

	$DepthInfo.visible = (len(screentouchplaces0pos) == 3)

	var fingerdown1posPP = plancamera.project_position(fingerdragpos, 0.0)
	plancameraxvec = plancamera.project_position(fingerdragpos+Vector2(1,0), 0.0) - fingerdown1posPP; 
	plancamerayvec = plancamera.project_position(fingerdragpos+Vector2(0,1), 0.0) - fingerdown1posPP; 
	plancamerazvec = plancameraxvec.length()*(plancamera.project_position(fingerdragpos, 1.0) - fingerdown1posPP)
	plancameratranslation = plancamera.translation
	plancameraroty = plancamera.rotation_degrees.y
	plancamerasize = plancamera.size


func updatescreentouchplaces0drag():
	var plancamera = planviewsystem.plancamera
	var planviewpositiondict = { }
	if touchedindrawmode:
		return
	if touchedinselectmode:
		return
	if not planviewsystem.visible:
		return

	if len(screentouchplaces0pos) == 1:
		var panvec = fingerdragpos - screentouchplaces0pos[screentouchposindex0]
		planviewpositiondict["plancamerapos"] = plancameratranslation + plancameraxvec*panvec.x + plancamerayvec*panvec.y

	elif len(screentouchplaces0pos) == 2:
		var screentouchplaces0kpos0 = screentouchplaces0pos[screentouchposindex0]
		var screentouchplaces0kpos1 = screentouchplaces0pos[screentouchposindex1]
		var fingerdragposN = (screentouchplaces0kpos0 + screentouchplaces0kpos1)*0.5
		var fingerdragvecN = screentouchplaces0kpos1 - screentouchplaces0kpos0
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

	elif len(screentouchplaces0pos) == 3:
		var screentouchplaces0kpos0 = screentouchplaces0pos[screentouchposindex0]
		var screentouchplaces0kpos1 = screentouchplaces0pos[screentouchposindex1]
		var screentouchplaces0kpos2 = screentouchplaces0pos[screentouchposindex2]
		var lfinger3a0 = finger3vector.dot(screentouchplaces0kpos0)
		var lfinger3a1 = finger3vector.dot(screentouchplaces0kpos1)
		var lfinger3a2 = finger3vector.dot(screentouchplaces0kpos2)
		var finger3elevrat = finger3elevdist/finger3camerafar
		var finger3a1rat = clamp((finger3a1 - finger3a0)/(finger3a2 - finger3a0), 0.05, 0.95)
		var lfinger3a1rat = clamp((lfinger3a1 - lfinger3a0)/(lfinger3a2 - lfinger3a0), 0.05, 0.95)

		var lplancamerafar = finger3camerafar * (lfinger3a2 - lfinger3a0)/(finger3a2 - finger3a0)
		var lfinger3elevrat = finger3elevrat*finger3camerafar/lplancamerafar
		var finger3pixratio = finger3camerafar/(finger3a2 - lfinger3a0) 
		var plancameradepthchange = finger3pixratio*(lfinger3a0 - finger3a0)

		planviewpositiondict["plancamerapos"] = plancameratranslation - plancameradepthchange*plancamera.transform.basis.z
		planviewpositiondict["plancameraelevcameradist"] = lfinger3a1rat*lplancamerafar
		planviewpositiondict["plancameraelevrotpoint"] = planviewpositiondict["plancamerapos"] + planviewpositiondict["plancameraelevcameradist"]*plancamera.transform.basis.z
		planviewpositiondict["plancamerafogdepthend"] = lplancamerafar
		planviewpositiondict["plancamerafogdepthbegin"] = (lplancamerafar + finger3elevdist)/2
		
	if len(planviewpositiondict) != 0:
		planviewsystem.actplanviewdict(planviewpositiondict)
		if len(screentouchplaces0pos) == 3:
			if plancamera.rotation_degrees.x == 0.0:
				$DepthInfo/Fields.text = "Elev: %.2f, Far: %.2f" % [ planviewsystem.elevcameradist, plancamera.far ]
			else:
				$DepthInfo/Fields.text = "Zhi: %.2f, Mid: %.2f, Zlo: %.2f" % [ plancamera.transform.origin.y, plancamera.transform.origin.y - planviewsystem.elevcameradist, plancamera.transform.origin.y - plancamera.far ]


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
			else:
				if len(screentouchplaces0pos) == 0:
					touchedindrawmode = $DrawmodeButton.pressed
					touchedinselectmode = $SelectmodeButton.pressed
				screentouchplaces[event.index] = 0
				screentouchplaces0pos[event.index] = event.position
				if touchedindrawmode or touchedinselectmode:
					updatescreentouchplaces0stateDraw(true)
					return
				else:
					updatescreentouchplaces0state(true)
		else:
			if screentouchplaces.get(event.index) == -1:
				$ThumbLeft/ThumbCircle.visible = false
				Tglobal.phonethumbviewposition = null
			elif screentouchplaces.get(event.index) == 1:
				$ThumbRight/ThumbCircle.visible = false
				Tglobal.phonethumbmotionposition = null
			elif screentouchplaces.get(event.index) == 0:
				screentouchplaces0pos.erase(event.index)
				if touchedindrawmode or touchedinselectmode:
					updatescreentouchplaces0stateDraw(false)
				else:
					updatescreentouchplaces0state(false)
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
			if touchedindrawmode or touchedinselectmode:
				updatescreentouchplaces0dragDraw()
			else:
				updatescreentouchplaces0drag()

var deviceaxisvalues = [ 0, 0, 0, 0, 0, 0, 0, 0 ]
func _input(event):
	if event is InputEventJoypadButton:
		print("Jbutton ", ("down" if event.pressed else "up"), " ", event.button_index)
		if event.device == 0 and event.button_index == 5 and event.pressed:
			print(" shunt the joystick data into LaserSelectLine")
	elif event is InputEventJoypadMotion:
		print("Jmotion ", event.axis, " dev ", event.device, " value ", (event.axis_value+1)/2*32767)
		if event.device == 0 and event.axis < 8:
			deviceaxisvalues[event.axis] = int((event.axis_value+1.0)/2*32767)
#	if not islefthand:

#		var a = (Input.get_joy_axis(0, 0)+1)/2*32768
#		var b = (Input.get_joy_axis(0, 1)+1)/2*32768
#		var c = (Input.get_joy_axis(0, 2)+1)/2*32768
#		print(int(a), " ", int(c), " ", Input.get_joy_name(0), " ", Input.get_joy_axis(0, 3), " ", Input.get_joy_axis(0, 4), " ", Input.get_joy_name(2), " ", Input.get_joy_axis(0, 5), " ", Input.get_joy_axis(0, 6))
#		$MeshInstance.rotation_degrees.x = a/30000*360-180
#		$MeshInstance.rotation_degrees.z = b/30000*360-90
#		$MeshInstance.rotation_degrees.y = c/30000*360-180
