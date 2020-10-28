extends Node

#const defaultfloordrawing = "http://cave-registry.org.uk/svn/NorthernEngland/ThreeCountiesArea/rawscans/Ireby/DukeStResurvey-drawnup-p3.jpg"
#const defaultfloordrawingres = "res://surveyscans/DukeStResurvey-drawnup-p3.jpg"
const defaultfloordrawing = "http://cave-registry.org.uk/svn/NorthernEngland/rawscans/LambTrap/LambTrap-drawnup-1.png"
const defaultfloordrawingres = "res://surveyscans/LambTrap-drawnup-1.png"

var imgdir = "user://northernimages/"
var nonimagedir = "user://nonimagewebpages/"
var urldir = "http://cave-registry.org.uk/svn/NorthernEngland/ThreeCountiesArea/rawscans/Ireby/"

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
	
func correctdefaultimgtrimtofull(d):
	var imgheight = d.imgwidth*d.imgheightwidthratio
	d.imgtrimleftdown = Vector2(-d.imgwidth*0.5, -imgheight*0.5)
	d.imgtrimrightup = Vector2(d.imgwidth*0.5, imgheight*0.5)

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
			print([1, fetcheddrawingfile, defaultfloordrawingres])
			if paperdrawing.xcresource == defaultfloordrawing:
				fetcheddrawingfile = defaultfloordrawingres
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
		if fetcheddrawingfile.begins_with("res://"):
			img = ResourceLoader.load(fetcheddrawingfile)  # imported as an Image, could be something else
		else:
			img.load(fetcheddrawingfile)
		print("FFF", [img, fetcheddrawing, fetcheddrawingfile])
		var papertexture = ImageTexture.new()
		papertexture.create_from_image(img)
		var fetcheddrawingmaterial = fetcheddrawing.get_node("XCdrawingplane/CollisionShape/MeshInstance").get_surface_material(0)
		#fetcheddrawingmaterial.albedo_texture = papertexture
		fetcheddrawingmaterial.set_shader_param("texture_albedo", papertexture)
		if papertexture.get_width() != 0:
			var previmgheightwidthratio = fetcheddrawing.imgheightwidthratio
			fetcheddrawing.imgheightwidthratio = papertexture.get_height()*1.0/papertexture.get_width()
			print("fff  ", fetcheddrawing.imgheightwidthratio)
			if previmgheightwidthratio == 0:
				correctdefaultimgtrimtofull(fetcheddrawing)				
			if fetcheddrawing.imgwidth != 0:
				fetcheddrawing.applytrimmedpaperuvscale()
				
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
	
