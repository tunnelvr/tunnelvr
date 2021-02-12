extends Spatial

const monospacefontcharwidth = 10
const monospacefontcharheight = 21
const maxlabelstorenderperimage = 20

var remainingxcnodenames = [ ]  # [ (centrelinedrawingname, name, position) ]
var remainingropelabels = [ ]   # [ (ropexcname, ropenodename, ropelabel) ]

var workingxccentrelinedrawingname = null
var workingxcnodenamelist = [ ]
var numcharsofeachline = [ ]
var workingropexcdrawingname = null
var workingropexcnodename = null

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
	for xcname in centrelinedrawing.nodepoints:
		if Tglobal.splaystationnoderegex == null or not Tglobal.splaystationnoderegex.search(xcname):
			remainingxcnodenames.append([centrelinedrawing.get_name(), xcname, centrelinedrawing.transform*centrelinedrawing.nodepoints[xcname]])
			if commonroot == null:
				commonroot = xcname.to_lower()
			else:
				while commonroot != "" and not xcname.to_lower().begins_with(commonroot):
					commonroot = commonroot.left(len(commonroot)-1)
	commonroot = commonroot.left(commonroot.find_last(",")+1)
	if commonroot == "":
		commonroot = "ireby2,"
	print("stationlabels common root: ", commonroot)
	sortdfunctorigin = get_node("/root/Spatial").playerMe.get_node("HeadCam").global_transform.origin

	
func restartlabelmakingprocess(lsortdfunctorigin=null):
	if get_node("/root/Spatial").playerMe.playerplatform != "Server":
		if len(remainingxcnodenames) != 0 or len(remainingropelabels) != 0:
			if lsortdfunctorigin != null:
				sortdfunctorigin = lsortdfunctorigin
				remainingxcnodenames.sort_custom(self, "sortdfunc")
			#print("restartlabelmakingprocess ", remainingropelabels, [workingropexcnodename, workingxcnodename])
			set_process(true)

func clearalllabelactivity():
	workingxcnodenamelist.clear()
	numcharsofeachline.clear()
	remainingxcnodenames.clear()
	workingropexcnodename = null
	remainingxcnodenames.clear()

func _process(delta):
	if len(workingxcnodenamelist) == 0 and workingropexcnodename == null and len(remainingropelabels) == 0:
		if len(remainingxcnodenames) == 0:
			set_process(false)
			return
		var planviewsystem = get_node("/root/Spatial/PlanViewSystem")
		if not planviewsystem.planviewcontrols.get_node("CheckBoxCentrelinesVisible").pressed:
			set_process(false)
			return

	if workingropexcnodename == null and len(workingxcnodenamelist) == 0:
		var labeltext
		numcharsofeachline = [ ]
		var maxnumchars = 0
		if len(remainingropelabels) != 0:
			workingropexcdrawingname = remainingropelabels.back()[0]
			workingropexcnodename = remainingropelabels.back()[1]
			labeltext = remainingropelabels.back()[2]
			remainingropelabels.pop_back()
			maxnumchars = len(labeltext)
			numcharsofeachline.push_back(maxnumchars)
		else:
			workingxccentrelinedrawingname = remainingxcnodenames.back()[0]
			while len(workingxcnodenamelist) < maxlabelstorenderperimage and len(remainingxcnodenames) != 0 and workingxccentrelinedrawingname == remainingxcnodenames.back()[0]:
				workingxcnodenamelist.push_back(remainingxcnodenames.back()[1])
				remainingxcnodenames.pop_back()

			var labeltextlines = [ ]
			maxnumchars = 0
			for lnodelabel in workingxcnodenamelist:
				if commonroot != "" and lnodelabel.to_lower().begins_with(commonroot):
					lnodelabel = lnodelabel.right(len(commonroot))
				lnodelabel = lnodelabel.replace(",", ".")
				labeltextlines.push_back(lnodelabel)
				numcharsofeachline.push_back(len(lnodelabel))
				maxnumchars = max(maxnumchars, len(lnodelabel))
			labeltext = PoolStringArray(labeltextlines).join("\n")

		$Viewport/RichTextLabel.bbcode_text = labeltext
		$Viewport.size.x = maxnumchars*monospacefontcharwidth  # monospace font
		$Viewport.size.y = monospacefontcharheight*len(numcharsofeachline)
		$Viewport/RichTextLabel.rect_size.x = $Viewport.size.x
		$Viewport/RichTextLabel.rect_size.y = $Viewport.size.y
		textlabelcountdowntimer = textlabelcountdowntime
		print("labeltextlabeltext ", len(workingxcnodenamelist), " of remaining ", len(remainingxcnodenames))
		$Viewport.render_target_update_mode = Viewport.UPDATE_ONCE

	elif textlabelcountdowntimer > 0.0:
		textlabelcountdowntimer -= delta
		
	elif workingropexcnodename != null:
		var img = $Viewport.get_texture().get_data()
		var tex = ImageTexture.new()
		tex.create_from_image(img)
		var workingropexcdrawing = get_node("/root/Spatial/SketchSystem/XCdrawings").get_node_or_null(workingropexcdrawingname)
		if workingropexcdrawing != null:
			var workingropexcnode = workingropexcdrawing.get_node("XCnodes").get_node_or_null(workingropexcnodename)
			if workingropexcnode != null:
				var ropelabelpanel = workingropexcnode.get_node("RopeLabel")
				ropelabelpanel.mesh.size.x = tex.get_width()*(ropelabelpanel.mesh.size.y/tex.get_height())
				var mat = ropelabelpanel.get_surface_material(0)
				mat.set_shader_param("texture_albedo", tex)
				mat.set_shader_param("vertex_offset", Vector3(-(ropelabelpanel.mesh.size.x*0.5 + 0.15), ropelabelpanel.mesh.size.y*0.5, 0))
				mat.set_shader_param("vertex_scale", 1.0)
		workingropexcnodename = null

	else:
		var img = $Viewport.get_texture().get_data()
		if len(workingxcnodenamelist) == maxlabelstorenderperimage:   img.save_png("user://test.png")
		var tex = ImageTexture.new()
		tex.create_from_image(img)
		
		var workingxccentrelinedrawing = get_node("/root/Spatial/SketchSystem/XCdrawings").get_node_or_null(workingxccentrelinedrawingname)
		if workingxccentrelinedrawing != null:
			for i in range(len(workingxcnodenamelist)):
				var workingxcnodename = workingxcnodenamelist[i]
				var lineimgwidth = numcharsofeachline[i]*monospacefontcharwidth
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
				xcnodelabelpanel.mesh.size.x = lineimgwidth*(xcnodelabelpanel.mesh.size.y/monospacefontcharheight)
				var mat = xcnodelabelpanel.get_surface_material(0)
				mat.set_shader_param("texture_albedo", tex)
				mat.set_shader_param("vertex_offset", Vector3(-(xcnodelabelpanel.mesh.size.x*0.5 + 0.15), xcnodelabelpanel.mesh.size.y*0.5, 0))
				mat.set_shader_param("vertex_scale", 1.0)
				mat.set_shader_param("uv1_scale", Vector3(lineimgwidth*1.0/tex.get_width(),1.0/len(workingxcnodenamelist),1))
				mat.set_shader_param("uv1_offset", Vector3(0,i*1.0/len(workingxcnodenamelist),0))

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
				xcnodelabelpanelp.mesh.size.x = lineimgwidth*(xcnodelabelpanelp.mesh.size.y/monospacefontcharheight)
				var matp = xcnodelabelpanelp.get_surface_material(0)
				matp.set_shader_param("texture_albedo", tex)
				matp.set_shader_param("vertex_offset", Vector3(-(xcnodelabelpanelp.mesh.size.x*0.5 + 0.15), xcnodelabelpanel.mesh.size.y*0.5, 0))
				matp.set_shader_param("vertex_scale", 1.0)
				#matp.set_shader_param("uv1_scale", Vector3(1,-1,1))
				matp.set_shader_param("uv1_scale", Vector3(lineimgwidth*1.0/tex.get_width(),-1.0/len(workingxcnodenamelist),1))
				matp.set_shader_param("uv1_offset", Vector3(0,(i+1)*1.0/len(workingxcnodenamelist),0))
				xcnodelabelpanelp.visible = true
		workingxcnodenamelist.clear()
