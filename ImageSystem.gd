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

func clearcachedir(dname):
	var dir = Directory.new()
	if not dir.dir_exists(dname):
		return
	var e = dir.open(dname)
	if e != OK:
		print("list dir error ", e)
		return
	var fnames = [ ]
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name != "." and file_name != "..":
			assert (not dir.current_is_dir())
			fnames.push_back(dname + file_name)
		file_name = dir.get_next()
	for fname in fnames:
		print("removing ", fname)
		var e1 = dir.remove(fname)
		if e1 != OK:
			print("remove file error ", e1)
	var e2 = dir.remove(dname)
	if e2 != OK:
		print("remove dir error ", e2)
			

var nFrame = 0
func _process(delta):
	nFrame += 1
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
			if paperdrawing.xcresource == defaultfloordrawing:
				fetcheddrawingfile = defaultfloordrawingres
				print("fetching default drawing file ", fetcheddrawingfile)
			if not File.new().file_exists(fetcheddrawingfile):
				if not Directory.new().dir_exists(imgdir):
					var err = Directory.new().make_dir(imgdir)
					print("Making directory ", imgdir, " err code: ", err)
				print("making httprequest ", paperdrawing.xcresource)
				httprequest = HTTPRequest.new()
				add_child(httprequest)
				httprequest.connect("request_completed", self, "_http_request_completed", [{"httprequest":httprequest, "paperdrawing":paperdrawing, "objectname":paperdrawing.get_name()}])
				httprequest.download_file = fetcheddrawingfile
				httprequest.request(paperdrawing.xcresource)
				httprequestduration = 0.0
			else:
				print("using cached image ", fetcheddrawingfile)
				fetcheddrawing = paperdrawing
		else:
			fetcheddrawingfile = "res://guimaterials/imagefilefailure.png"

	elif fetcheddrawing != null:
		var img = null
		if fetcheddrawingfile.begins_with("res://"):
			img = ResourceLoader.load(fetcheddrawingfile)  # imported as an Image, could be something else
		else:
			var fimg = File.new()
			fimg.open(fetcheddrawingfile, File.READ)
			var fimglen = fimg.get_len()
			fimg.close()
			if fimglen < 1.5*1000000:
				img = Image.new()
				var t0 = OS.get_ticks_msec()
				img.load(fetcheddrawingfile)
				var dt = OS.get_ticks_msec() - t0
				if dt > 100:
					print("Warning: file ", fetcheddrawingfile, " size ", fimglen, " bytes took ", dt, " msecs to decode")
			else:
				print("Skipping big image file ", fetcheddrawingfile, " size ", fimglen, " bytes")
				img = null
		
		if img != null:
			var papertexture = ImageTexture.new()
			papertexture.create_from_image(img)
			if papertexture.get_width() != 0:
				var fetcheddrawingmaterial = fetcheddrawing.get_node("XCdrawingplane/CollisionShape/MeshInstance").get_surface_material(0)
				fetcheddrawingmaterial.set_shader_param("texture_albedo", papertexture)
				var previmgheightwidthratio = fetcheddrawing.imgheightwidthratio
				fetcheddrawing.imgheightwidthratio = papertexture.get_height()*1.0/papertexture.get_width()
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
		pass # set_process(false)

func fetchunrolltree(fileviewtree, item, url):
	var nonimagedataobject = { "url":url, "tree":fileviewtree, "item":item }
	nonimagepageslist.append(nonimagedataobject)
	set_process(true)

func fetchpaperdrawing(paperdrawing):
	paperdrawinglist.append(paperdrawing)
	set_process(true)
	
