extends Spatial

const charwidth = 10
var remainingxcnodenames = [ ]  # [ (centrelinedrawingnamme, name, position) ]
var workingxccentrelinedrawingname = null
var workingxcnodename = null
const XCnode_centreline = preload("res://nodescenes/XCnode_centreline.tscn")
const XCnode_centrelineplanview = preload("res://nodescenes/XCnode_centrelineplanview.tscn")

const textlabelcountdowntime = 0.2
var textlabelcountdowntimer = 0.0

var sortdfunctorigin = Vector3(0,0,0)
func sortdfunc(a, b):
	return sortdfunctorigin.distance_squared_to(a[2]) > sortdfunctorigin.distance_squared_to(b[2])

var stationnodematerial = null
func _ready():
	var materialsystem = get_node("/root/Spatial/MaterialSystem")
	stationnodematerial = materialsystem.nodematerial("station")
	set_process(false)
			
var commonroot = null
func addnodestolabeltask(centrelinedrawing):
	for xcn in centrelinedrawing.get_node("XCnodes").get_children():
		remainingxcnodenames.append([centrelinedrawing.get_name(), xcn.get_name(), xcn.global_transform.origin])
		if commonroot == null:
			commonroot = xcn.get_name()
		else:
			while commonroot != "" and not xcn.get_name().begins_with(commonroot):
				commonroot = commonroot.left(len(commonroot)-1)
	commonroot = commonroot.left(commonroot.find_last(",")+1)
	if commonroot == "":
		commonroot = "Ireby2,"
	sortdfunctorigin = get_node("/root/Spatial").playerMe.get_node("HeadCam").global_transform.origin

func addnodestolabeltaskN(centrelinedrawing):
	for xcname in centrelinedrawing.nodepoints:
		remainingxcnodenames.append([centrelinedrawing.get_name(), xcname, centrelinedrawing.transform*centrelinedrawing.nodepoints[xcname]])
		if commonroot == null:
			commonroot = xcname
		else:
			while commonroot != "" and not xcname.begins_with(commonroot):
				commonroot = commonroot.left(len(commonroot)-1)
	commonroot = commonroot.left(commonroot.find_last(",")+1)
	print("stationlabels common root: ", commonroot)
	sortdfunctorigin = get_node("/root/Spatial").playerMe.get_node("HeadCam").global_transform.origin

	
func restartlabelmakingprocess(lsortdfunctorigin):
	if get_node("/root/Spatial").playerMe.playerplatform != "Server":
		sortdfunctorigin = lsortdfunctorigin
		if len(remainingxcnodenames) != 0:
			remainingxcnodenames.sort_custom(self, "sortdfunc")
			set_process(true)

func _process(delta):
	if workingxcnodename == null:
		if len(remainingxcnodenames) == 0:
			set_process(false)
			return
		var planviewsystem = get_node("/root/Spatial/PlanViewSystem")
		if not planviewsystem.visible and not planviewsystem.planviewcontrols.get_node("CheckBoxTubesVisible").pressed:
			set_process(false)
			return

	if workingxcnodename == null:
		workingxccentrelinedrawingname = remainingxcnodenames.back()[0]
		workingxcnodename = remainingxcnodenames.back()[1]
		remainingxcnodenames.pop_back()
		var labeltext = workingxcnodename
		if commonroot != "":
			labeltext = labeltext.right(len(commonroot))
		labeltext = labeltext.replace(",", ".")
		var numchars = len(labeltext)
		var labelwidth = numchars*charwidth  # monospace font
		$Viewport/RichTextLabel.bbcode_text = labeltext
		$Viewport/RichTextLabel.rect_size.x = labelwidth
		$Viewport.size.x = labelwidth
		textlabelcountdowntimer = textlabelcountdowntime
		$Viewport.render_target_update_mode = Viewport.UPDATE_ONCE
	elif textlabelcountdowntimer > 0.0:
		textlabelcountdowntimer -= delta
	else:
		var img = $Viewport.get_texture().get_data()
		var tex = ImageTexture.new()
		tex.create_from_image(img)
		var workingxccentrelinedrawing = get_node("/root/Spatial/SketchSystem/XCdrawings").get_node_or_null(workingxccentrelinedrawingname)
		if workingxccentrelinedrawing != null:
			var workingxcnode = workingxccentrelinedrawing.get_node("XCnodes").get_node_or_null(workingxcnodename)
			if workingxcnode == null:
				workingxcnode = XCnode_centreline.instance()
				workingxcnode.set_name(workingxcnodename)
				workingxcnode.get_node("CollisionShape/MeshInstance").layers = CollisionLayer.VL_centrelinestations
				workingxcnode.get_node("StationLabel").layers = CollisionLayer.VL_centrelinestationslabel
				workingxcnode.get_node("CollisionShape/MeshInstance").set_surface_material(0, stationnodematerial)
				workingxcnode.collision_layer = CollisionLayer.CL_CentrelineStation
				workingxcnode.translation = workingxccentrelinedrawing.nodepoints[workingxcnodename]
				workingxccentrelinedrawing.get_node("XCnodes").add_child(workingxcnode)
			var xcnodelabelpanel = workingxcnode.get_node("StationLabel")
			xcnodelabelpanel.mesh.size.x = tex.get_width()*(xcnodelabelpanel.mesh.size.y/tex.get_height())
			var mat = xcnodelabelpanel.get_surface_material(0)
			mat.set_shader_param("texture_albedo", tex)
			mat.set_shader_param("vertex_offset", Vector3(-(xcnodelabelpanel.mesh.size.x*0.5 + 0.15), xcnodelabelpanel.mesh.size.y*0.5, 0))
			mat.set_shader_param("vertex_scale", 1.0)
			xcnodelabelpanel.visible = false

			var workingxcnodeplanview = workingxccentrelinedrawing.get_node("XCnodes_PlanView").get_node_or_null(workingxcnodename)
			if workingxcnodeplanview == null:
				workingxcnodeplanview = XCnode_centrelineplanview.instance()
				workingxcnodeplanview.set_name(workingxcnodename)
				workingxcnodeplanview.get_node("CollisionShape/MeshInstance").layers = CollisionLayer.VL_centrelinestationsplanview
				workingxcnodeplanview.get_node("StationLabel").layers = CollisionLayer.VL_centrelinestationslabelplanview
				workingxcnodeplanview.get_node("CollisionShape/MeshInstance").set_surface_material(0, stationnodematerial)
				workingxcnodeplanview.collision_layer = CollisionLayer.CL_CentrelineStationPlanView
				workingxcnodeplanview.translation = workingxccentrelinedrawing.nodepoints[workingxcnodename]
				workingxccentrelinedrawing.get_node("XCnodes_PlanView").add_child(workingxcnodeplanview)
			var xcnodelabelpanelp = workingxcnodeplanview.get_node("StationLabel")
			xcnodelabelpanelp.mesh.size.x = tex.get_width()*(xcnodelabelpanelp.mesh.size.y/tex.get_height())
			var matp = xcnodelabelpanelp.get_surface_material(0)
			matp.set_shader_param("texture_albedo", tex)
			matp.set_shader_param("vertex_offset", Vector3(-(xcnodelabelpanelp.mesh.size.x*0.5 + 0.15), xcnodelabelpanel.mesh.size.y*0.5, 0))
			matp.set_shader_param("vertex_scale", 1.0)
			matp.set_shader_param("uv1_scale", Vector3(1,-1,1))
			xcnodelabelpanelp.visible = true

		workingxcnodename = null
