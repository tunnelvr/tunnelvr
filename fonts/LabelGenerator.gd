extends Spatial

const charwidth = 10
var remainingxcnodes = [ ]
var workingxcnode = null

const textlabelcountdowntime = 0.2
var textlabelcountdowntimer = 0.0

var sortdfunctorigin = Vector3(0,0,0)
func sortdfunc(a, b):
	return sortdfunctorigin.distance_squared_to(a.global_transform.origin) > sortdfunctorigin.distance_squared_to(b.global_transform.origin)

var commonroot = null
func addnodestolabeltask(centrelinedrawing):
	for xcn in centrelinedrawing.get_node("XCnodes").get_children():
		remainingxcnodes.append(xcn)
		sortdfunctorigin = get_node("/root/Spatial").playerMe.get_node("HeadCam").global_transform.origin
		if commonroot == null:
			commonroot = xcn.get_name()
		else:
			while commonroot != "" and not xcn.get_name().begins_with(commonroot):
				commonroot = commonroot.left(len(commonroot)-1)
	commonroot = commonroot.left(commonroot.find_last(",")+1)
	
func restartlabelmakingprocess(lsortdfunctorigin):
	sortdfunctorigin = lsortdfunctorigin
	if len(remainingxcnodes) != 0:
		remainingxcnodes.sort_custom(self, "sortdfunc")
		set_process(true)

func _process(delta):
	if workingxcnode == null and (len(remainingxcnodes) == 0 or not Tglobal.centrelinevisible):
		set_process(false)
	elif workingxcnode == null:
		workingxcnode = remainingxcnodes.pop_back()
		var labeltext = workingxcnode.get_name()
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
		var xcnodelabelpanel = workingxcnode.get_node("StationLabel")
		xcnodelabelpanel.mesh.size.x = tex.get_width()*(xcnodelabelpanel.mesh.size.y/tex.get_height())
		xcnodelabelpanel.get_surface_material(0).set_shader_param("texture_albedo", tex)
		#xcnodelabelpanel.get_surface_material(0).albedo_texture = tex
		xcnodelabelpanel.get_surface_material(0).set_shader_param("vertex_offset", Vector3(xcnodelabelpanel.mesh.size.x*0.5 + 0.3, xcnodelabelpanel.mesh.size.y*0.5, 0))
		xcnodelabelpanel.get_surface_material(0).set_shader_param("vertex_scale", 1.0)
		xcnodelabelpanel.visible = true
		workingxcnode = null
