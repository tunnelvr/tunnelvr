extends Spatial

const charwidth = 10
var remainingxcnodes = [ ]
var workingxcnode = null

const textlabelcountdowntime = 0.2
var textlabelcountdowntimer = 0.0
var centrelinevisible = false

func makenodelabelstask(centrelinedrawing, addtolabelgeneratingtask, lcentrelinevisible):
	centrelinevisible = lcentrelinevisible
	for xcn in centrelinedrawing.get_node("XCnodes").get_children():
		xcn.get_node("Quad").visible = centrelinevisible
		if addtolabelgeneratingtask:
			remainingxcnodes.append(xcn)
	centrelinedrawing.get_node("PathLines").visible = centrelinevisible
	$ViewportForceRender.visible = centrelinevisible
	set_process(centrelinevisible)

func _process(delta):
	if not centrelinevisible:
		set_process(false)
		return
	if workingxcnode == null:
		if len(remainingxcnodes) == 0:
			set_process(false)
			$ViewportForceRender.visible = false
			return
		workingxcnode = remainingxcnodes.pop_back()
		var labeltext = workingxcnode.get_name()
		var numchars = len(labeltext)
		var labelwidth = numchars*charwidth  # monospace font
		$Viewport/RichTextLabel.bbcode_text = labeltext
		$Viewport/RichTextLabel.rect_size.x = labelwidth
		$Viewport.size.x = labelwidth
		textlabelcountdowntimer = textlabelcountdowntime
	elif textlabelcountdowntimer > 0.0:
		textlabelcountdowntimer -= delta
	else:
		var img = $Viewport.get_texture().get_data()
		var tex = ImageTexture.new()
		tex.create_from_image(img)
		var xcnodelabelpanel = workingxcnode.get_node("Quad")
		#xcnodelabelpanel.get_surface_material(0).albedo_texture = tex
		xcnodelabelpanel.mesh.size.x = tex.get_width()*(xcnodelabelpanel.mesh.size.y/tex.get_height())
		xcnodelabelpanel.get_surface_material(0).set_shader_param("texture_albedo", tex)
		xcnodelabelpanel.get_surface_material(0).set_shader_param("vertex_offset", Vector3(xcnodelabelpanel.mesh.size.x*0.5 + 0.3, xcnodelabelpanel.mesh.size.y*0.5, 0))
		xcnodelabelpanel.get_surface_material(0).set_shader_param("vertex_scale", 1.0)
		xcnodelabelpanel.visible = true
		workingxcnode = null
