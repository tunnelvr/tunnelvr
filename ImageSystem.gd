extends Node

const defaultfloordrawing = "http://cave-registry.org.uk/svn/NorthernEngland/ThreeCountiesArea/rawscans/Ireby/DukeStResurvey-drawnup-p3.jpg"
const defaultfloordrawingres = "res://surveyscans/DukeStResurvey-drawnup-p3.jpg"

var imgdir = "user://northernimages/"
var nonimagedir = "user://nonimagewebpages/"
var urldir = "http://cave-registry.org.uk/svn/NorthernEngland/ThreeCountiesArea/rawscans/Ireby/"


var imglistD = [ "BoltonExtensionsResurvey-DrawnUpSketch-1.jpg", 
				"DukeStResurvey-drawnup-p1.jpg", 
				"DukeStResurvey-drawnup-p2.jpg", 
				"DukeStResurvey-drawnup-p3.jpg", 
				"DukeStParallelSidePassage-DrawnUp1.jpg",
				"DukeStParallelSidePassage-DrawnUp2.jpg"
			   ]
				
var imglist = [ "DukeSt2sanddig.jpg",
				"Canal2-drawnup.jpg",
				"dukest2tocanal-drawnup.jpg",
				"WhirlpoolCrawl-drawnup-p1.jpg",
				"escalatorclimb-drawnup-1.jpg",
				"DukeSt2inletsump.jpg",
				"IrebyII.jpg",
				"DukeSt2-TidyUp-P3.jpg",
				"jupiter2irebyone_5.jpg",
				"jupiter2irebyone_4.jpg"
			  ]
var paperwidth = 0.4

func getshortimagename(xcresource, withextension, md5nameleng):
	var fname = xcresource.substr(xcresource.find_last("/")+1)
	var ext = xcresource.get_extension()
	if ext != null and ext != "":
		ext = "."+ext
	fname = fname.get_basename()
	fname = fname.replace(".", "").replace("@", "").replace("%", "")
	var md5name = xcresource.md5_text().substr(0, md5nameleng)
	if len(fname) > 8:
		fname = fname.substr(0,4)+md5name+fname.substr(len(fname)-4)
	else:
		fname = fname+md5name
	return fname+ext if withextension else fname


var paperdrawinglist = [ ]
var nonimagepageslist = [ ]

var imagefetchingcountdowntimer = 0.0
var imagefetchingcountdowntime = 0.15
var fetcheddrawing = null
var fetchednonimagedataobject = null
var httprequest = null
var httprequestduration = 0.0
var fetcheddrawingfile = null
var fetchednonimagedataobjectfile = null

func _http_request_completed(result, response_code, headers, body, httprequestdataobject):
	if httprequestdataobject["httprequest"] != httprequest:
		print("_http_request_completed ")
	httprequestdataobject["httprequest"].queue_free()
	if response_code == 200:
		if "paperdrawing" in httprequestdataobject:
			fetcheddrawing = httprequestdataobject["paperdrawing"]
		else:
			fetchednonimagedataobject = httprequestdataobject
	else:
		print("http response code bad ", response_code, " for ", httprequestdataobject)
		if "paperdrawing" in httprequestdataobject:
			fetcheddrawing = httprequestdataobject["paperdrawing"]
			fetcheddrawingfile = "res://guimaterials/imagefilefailure.png"
		else:
			fetchednonimagedataobject = httprequestdataobject
			fetchednonimagedataobject["bad_response_code"] = response_code
	httprequest = null
	
func _process(delta):
	if imagefetchingcountdowntimer > 0.0:
		imagefetchingcountdowntimer -= delta
		return
	imagefetchingcountdowntimer = imagefetchingcountdowntime

	if fetcheddrawing == null and fetchednonimagedataobject == null and httprequest == null and len(nonimagepageslist) > 0:
		var nonimagepage = nonimagepageslist.pop_front()
		nonimagepage["fetchednonimagedataobjectfile"] = nonimagedir+getshortimagename(nonimagepage["url"], true, 20)
		if not File.new().file_exists(nonimagepage["fetchednonimagedataobjectfile"]):
			if not Directory.new().dir_exists(nonimagedir):
				var err = Directory.new().make_dir(nonimagedir)
				print("Making directory ", nonimagedir, " err code: ", err)
			httprequest = HTTPRequest.new()
			add_child(httprequest)
			nonimagepage["httprequest"] = httprequest
			httprequest.connect("request_completed", self, "_http_request_completed", [nonimagepage])
			httprequest.download_file = nonimagepage["fetchednonimagedataobjectfile"]
			httprequest.request(nonimagepage["url"])
			httprequestduration = 0.0
		else:
			fetchednonimagedataobject = nonimagepage

	if fetcheddrawing == null and fetchednonimagedataobject == null and httprequest == null and len(paperdrawinglist) > 0:
		var paperdrawing = paperdrawinglist.pop_front()
		if paperdrawing.xcresource.begins_with("res://"):
			fetcheddrawingfile = paperdrawing.xcresource
			fetcheddrawing = paperdrawing
			if not File.new().file_exists(fetcheddrawingfile):
				fetcheddrawingfile = "res://guimaterials/imagefilefailure.png"
		elif paperdrawing.xcresource.begins_with("http"):
			fetcheddrawingfile = imgdir+getshortimagename(paperdrawing.xcresource, true, 6)
			print([paperdrawing.xcresource, defaultfloordrawing])
			print([1, fetcheddrawingfile])
			#if paperdrawing.xcresource == defaultfloordrawing:
			#	fetcheddrawingfile = defaultfloordrawingres
			if not File.new().file_exists(fetcheddrawingfile):
				if not Directory.new().dir_exists(imgdir):
					var err = Directory.new().make_dir(imgdir)
					print("Making directory ", imgdir, " err code: ", err)
				httprequest = HTTPRequest.new()
				add_child(httprequest)
				httprequest.connect("request_completed", self, "_http_request_completed", [{"httprequest":httprequest, "paperdrawing":paperdrawing, "objectname":paperdrawing.get_name()}])
				httprequest.download_file = fetcheddrawingfile
				httprequest.request(paperdrawing.xcresource)
				httprequestduration = 0.0
			else:
				fetcheddrawing = paperdrawing
		else:
			fetcheddrawingfile = "res://guimaterials/imagefilefailure.png"

	elif fetcheddrawing != null:
		var img = Image.new()
		print("FFF", [fetcheddrawing, fetcheddrawingfile])
		img.load(fetcheddrawingfile)
		var papertexture = ImageTexture.new()
		papertexture.create_from_image(img)
		var fetcheddrawingmaterial = fetcheddrawing.get_node("XCdrawingplane/CollisionShape/MeshInstance").get_surface_material(0)
		#fetcheddrawingmaterial.albedo_texture = papertexture
		fetcheddrawingmaterial.set_shader_param("texture_albedo", papertexture)
		if papertexture.get_width() != 0:
			fetcheddrawing.imgheightwidthratio = papertexture.get_height()*1.0/papertexture.get_width()
			print("fff  ", fetcheddrawing.imgheightwidthratio)
			if fetcheddrawing.imgwidth == 0:
				var drawingplane = fetcheddrawing.get_node("XCdrawingplane")
				fetcheddrawing.imgwidth = drawingplane.scale.x*2
				drawingplane.scale.y = (fetcheddrawing.imgwidth*0.5)*fetcheddrawing.imgheightwidthratio
				fetcheddrawing.imgtrimleftdown = Vector2(-drawingplane.scale.x, -drawingplane.scale.y)
				fetcheddrawing.imgtrimrightup = Vector2(drawingplane.scale.x, drawingplane.scale.y)
				#fetcheddrawingmaterial.uv1_scale = Vector3(1,1,1)
				#fetcheddrawingmaterial.uv1_offset = Vector3(0,0,0)
				fetcheddrawingmaterial.set_shader_param("uv1_scale", Vector3(1,1,1))
				fetcheddrawingmaterial.set_shader_param("uv1_offset", Vector3(0,0,0))
				
		else:
			print(fetcheddrawingfile, "   has zero width, deleting")
			Directory.new().remove(fetcheddrawingfile)
			
		fetcheddrawing = null

	elif fetchednonimagedataobject != null:
		print("FFFN ", fetchednonimagedataobject)
		if "tree" in fetchednonimagedataobject:
			var htmltextfile = File.new()
			htmltextfile.open(fetchednonimagedataobject["fetchednonimagedataobjectfile"], File.READ)
			var htmltext = htmltextfile.get_as_text()
			htmltextfile.close()
			get_node("/root/Spatial/PlanViewSystem").openlinklistpage(fetchednonimagedataobject["item"], htmltext)
		fetchednonimagedataobject = null

	elif httprequest != null:
		httprequestduration += delta

	else:
		set_process(false)

func fetchunrolltree(tree, item, url):
	var nonimagedataobject = { "url":url, "tree":tree, "item":item }
	nonimagepageslist.append(nonimagedataobject)
	set_process(true)

func fetchpaperdrawing(paperdrawing):
	paperdrawinglist.append(paperdrawing)
	set_process(true)
	
func fetchimportpapers():
	var player = get_node("/root/Spatial").playerMe
	var playerhead = player.get_node("HeadCam")
	var playerhgaze = Vector3(playerhead.global_transform.basis.z.x, 0, playerhead.global_transform.basis.z.z).normalized()
	var paperorg = Vector3(player.global_transform.origin) + Vector3(0, 0.2, 0) - playerhgaze*2.3
	var lookvec = paperorg - (playerhead.global_transform.origin + Vector3(0,0.9,0))
	var papertransorg = Transform(Basis(), paperorg).looking_at(paperorg + lookvec, Vector3(0,1,0))
	for i in range(len(imglist)):
		var papertrans = Transform(papertransorg.basis, papertransorg.origin 
									+ papertransorg.basis.x*((i%5)-2)*(paperwidth + 0.05) 
									+ papertransorg.basis.z*(i%2)*(paperwidth*0.2) 
									+ Vector3(0, int(i/5+1)*(paperwidth*0.6+0.05), 0))

		var paperdrawing = get_node("/root/Spatial/SketchSystem").newXCuniquedrawingPaper(urldir+imglist[i], DRAWING_TYPE.DT_PAPERTEXTURE)
		paperdrawing.global_transform = papertrans
		paperdrawing.get_node("XCdrawingplane").scale = Vector3(paperwidth/2, paperwidth/2, 1)
		#get_node("/root/Spatial/SketchSystem").sharexcdrawingovernetwork(paperdrawing)
		fetchpaperdrawing(paperdrawing)

#func _input(event):
#	if event is InputEventKey and event.pressed and event.scancode == KEY_V:
#		fetchimportpapers()
