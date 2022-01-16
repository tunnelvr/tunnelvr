extends Control


var thumbarearadius = 50
func setupphoneoverlaysystem():
	visible = true
	Tglobal.phoneoverlay = self
	var n = 16
	print($ThumbLeft/CollisionShape2D.shape)
	var screensize = get_node("/root").size
	thumbarearadius = min(screensize.x, screensize.y)/4.5
	var thumbareamargin = thumbarearadius/7
	$ThumbLeft/CollisionShape2D.shape.radius = thumbarearadius

	var pts = [ ]
	for i in range(16):
		pts.push_back(Vector2(cos(deg2rad(360.0*i/n)), sin(deg2rad(360.0*i/n)))*thumbarearadius); 
	$ThumbLeft/TouchCircle.set_polygon(PoolVector2Array(pts))
	$ThumbLeft/ThumbCircle.set_polygon(PoolVector2Array(pts))
	$ThumbLeft.transform.origin = Vector2(thumbareamargin + thumbarearadius, screensize.y - thumbarearadius - thumbareamargin)
	$ThumbLeft.connect("input_event", self, "thumbviewinput")	
	$ThumbLeft/CollisionShape2D.disabled = false
	
	$ThumbRight/TouchCircle.set_polygon(PoolVector2Array(pts))
	$ThumbRight/ThumbCircle.set_polygon(PoolVector2Array(pts))
	$ThumbRight.transform.origin = Vector2(screensize.x - thumbareamargin - thumbarearadius, screensize.y - thumbarearadius - thumbareamargin)
	$ThumbRight.connect("input_event", self, "thumbmotioninput")
	$ThumbRight/CollisionShape2D.disabled = false

	var thumgapsize = screensize.x - 4*thumbareamargin - 4*thumbarearadius

	var guipanel3dviewport = get_node("/root/Spatial/GuiSystem/GUIPanel3D/Viewport")
	var orgpanelsize = guipanel3dviewport.get_node("GUI").rect_size
	var panelscale = min(thumgapsize/orgpanelsize.x, (screensize.y-2*thumbareamargin/orgpanelsize.y))

	guipanel3dviewport.rect_scale = Vector2(panelscale, panelscale)
	guipanel3dviewport.rect_position = Vector2(screensize.x/2 - orgpanelsize.x*panelscale/2, screensize.y - orgpanelsize.y*panelscale - thumbareamargin)
	guipanel3dviewport.visible = false

	$MenuButton.rect_position = guipanel3dviewport.rect_position + Vector2(orgpanelsize.x*panelscale/2, orgpanelsize.y*panelscale) - $MenuButton.rect_size*panelscale
	$MenuButton.rect_scale = Vector2(panelscale, panelscale)
	$MenuButton.connect("pressed", self, "menubuttonpressed")
	
	
func menubuttonpressed():
	var guipanel3dviewport = get_node("/root/Spatial/GuiSystem/GUIPanel3D/Viewport")
	if guipanel3dviewport.visible:
		get_node("/root/Spatial/GuiSystem/GUIPanel3D").setguipanelhide()
	else:
		get_node("/root/Spatial/GuiSystem/GUIPanel3D").setguipanelvisible(null)

func thumbmotioninput(viewport: Object, event: InputEvent, shape_idx: int):
	if event is InputEventMouseButton:
		if event.button_index == 1:
			if event.pressed:
				$ThumbRight/ThumbCircle.visible = true
			else:
				$ThumbRight/ThumbCircle.visible = false
				Tglobal.phonethumbmotionposition = null
	if $ThumbRight/ThumbCircle.visible and (event is InputEventMouseMotion or event is InputEventMouseButton):
		Tglobal.phonethumbmotionposition = (event.position - $ThumbRight.transform.origin)/thumbarearadius
		$ThumbRight/ThumbCircle.transform.origin = Tglobal.phonethumbmotionposition*thumbarearadius
	
func thumbviewinput(viewport: Object, event: InputEvent, shape_idx: int):
	if event is InputEventMouseButton:
		if event.button_index == 1:
			if event.pressed:
				$ThumbLeft/ThumbCircle.visible = true
			else:
				$ThumbLeft/ThumbCircle.visible = false
				Tglobal.phonethumbviewposition = null
	if $ThumbLeft/ThumbCircle.visible and (event is InputEventMouseMotion or event is InputEventMouseButton):
		Tglobal.phonethumbviewposition = (event.position - $ThumbLeft.transform.origin)/thumbarearadius
		$ThumbLeft/ThumbCircle.transform.origin = Tglobal.phonethumbviewposition*thumbarearadius
