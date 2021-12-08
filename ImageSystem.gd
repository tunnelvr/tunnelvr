extends Node

#const defaultfloordrawing = "http://cave-registry.org.uk/svn/NorthernEngland/ThreeCountiesArea/rawscans/Ireby/DukeStResurvey-drawnup-p3.jpg"
#const defaultfloordrawingres = "res://surveyscans/DukeStResurvey-drawnup-p3.jpg"
const defaultfloordrawing = "http://cave-registry.org.uk/svn/NorthernEngland/rawscans/LambTrap/LambTrap-drawnup-1.png"
const defaultfloordrawingres = "res://surveyscans/LambTrap-drawnup-1.png"

var imgdir = "user://northernimages/"
var nonimagedir = "user://nonimagewebpages/"
var listregex = RegEx.new()

var paperdrawinglist = [ ]
var nonimagepageslist = [ ]

var imagefetchingcountdowntimer = 0.0
var imagefetchingcountdowntime = 0.15
var fetcheddrawing = null

var fetchednonimagedataobject = null
var httprequest = null
var httprequestduration = 0.0
var fetcheddrawingfile = null

var imageloadingthreadmutex = Mutex.new()
var imageloadingthreadsemaphore = Semaphore.new()
var imageloadingthread = Thread.new()
var imageloadingthreadoperating = false
var imageloadingthreaddrawingfile = null
var imageloadingthreadloadedimagetexture = null
var imagethreadloadedflags = Texture.FLAG_MIPMAPS|Texture.FLAG_REPEAT # |Texture.FILTER

onready var imagesystemreportslabel = get_node("/root/Spatial/GuiSystem/GUIPanel3D/Viewport/GUI/Panel/ImageSystemReports")

func imageloadingthread_function(userdata):
	print("imageloadingthread_function started")
	while true:
		imageloadingthreadsemaphore.wait()

		imageloadingthreadmutex.lock()
		var limageloadingthreaddrawingfile = imageloadingthreaddrawingfile
		imageloadingthreaddrawingfile = null
		imageloadingthreadmutex.unlock()

		if limageloadingthreaddrawingfile == null:
			break
		var t0 = OS.get_ticks_msec()
		var limageloadingthreadloadedimage
		if limageloadingthreaddrawingfile.begins_with("res://"):
			limageloadingthreadloadedimage = ResourceLoader.load(limageloadingthreaddrawingfile)
		else:
			limageloadingthreadloadedimage = Image.new()
			limageloadingthreadloadedimage.load(limageloadingthreaddrawingfile)
		var dt = OS.get_ticks_msec() - t0
		if dt > 100:
			print("thread loading ", limageloadingthreaddrawingfile, " took ", dt, " msecs")
		var limageloadingthreadloadedimagetexture = ImageTexture.new()
		limageloadingthreadloadedimagetexture.create_from_image(limageloadingthreadloadedimage, imagethreadloadedflags)
		imageloadingthreadmutex.lock()
		imageloadingthreadloadedimagetexture = limageloadingthreadloadedimagetexture
		imageloadingthreadmutex.unlock()

func _exit_tree():
	imageloadingthreadmutex.lock()
	imageloadingthreaddrawingfile = null
	imageloadingthreadmutex.unlock()
	imageloadingthreadsemaphore.post()
	imageloadingthread.wait_to_finish()

func _ready():
	imageloadingthread.start(self, "imageloadingthread_function")
	listregex.compile('<li><a href="([^"]*)">')
	
func clearallimageloadingactivity():
	fetcheddrawing = null
	paperdrawinglist.clear()

func _http_request_completed(result, response_code, headers, body, httprequestdataobject):
	#print("_http_request_completed ", len(body), " bytes", headers)
	httprequestdataobject["httprequest"].queue_free()
	if response_code == 200 or response_code == 206:
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
			

func getshortimagename(xcresource, withextension, md5nameleng, nonimagepage={}):
	var fname = xcresource.substr(xcresource.find_last("/")+1)
	var ext = xcresource.get_extension()
	if ext != null and ext != "":
		ext = "."+ext
	fname = fname.get_basename()
	fname = fname.replace(".", "").replace("@", "").replace("%", "")
	var md5name = xcresource.md5_text().substr(0, md5nameleng)
	var extname = ""
	if nonimagepage.has("byteOffset"):
		extname = "_%d_%d" % [nonimagepage["byteOffset"], nonimagepage["byteSize"]]
	if len(fname) > 8:
		fname = fname.substr(0,4)+md5name+extname+fname.substr(len(fname)-4)
	else:
		fname = fname+md5name+extname
	return fname+ext if withextension else fname


var nFrame = 0
func _process(delta):
	nFrame += 1
	if imagefetchingcountdowntimer > 0.0:
		imagefetchingcountdowntimer -= delta
		return
	imagefetchingcountdowntimer = imagefetchingcountdowntime
	
	var t0 = OS.get_ticks_msec()
	var pt = ""
	if fetcheddrawing == null and fetchednonimagedataobject == null and httprequest == null and len(nonimagepageslist) > 0:
		var nonimagepage = nonimagepageslist.pop_front()
		nonimagepage["fetchednonimagedataobjectfile"] = nonimagedir + \
			getshortimagename(nonimagepage["url"], true, 
							  (10 if nonimagepage.has("byteOffset") else 20), 
							  nonimagepage)
		if not File.new().file_exists(nonimagepage["fetchednonimagedataobjectfile"]):
			if not Directory.new().dir_exists(nonimagedir):
				var err = Directory.new().make_dir(nonimagedir)
				print("Making directory ", nonimagedir, " err code: ", err)
			httprequest = HTTPRequest.new()
			var headers = nonimagepage.get("headers", [])
			add_child(httprequest)
			nonimagepage["httprequest"] = httprequest
			httprequest.connect("request_completed", self, "_http_request_completed", [nonimagepage])
			httprequest.download_file = nonimagepage["fetchednonimagedataobjectfile"]
			if nonimagepage.has("byteOffset"):
				headers.push_back("Range: bytes=%d-%d" % [nonimagepage["byteOffset"], nonimagepage["byteOffset"]+nonimagepage["byteSize"]-1])
			print("makinghttprequest ", nonimagepage["fetchednonimagedataobjectfile"], nonimagepage.get("byteOffset"))
			httprequest.request(nonimagepage["url"], headers)
			httprequestduration = 0.0
			imagesystemreportslabel.text = "%d-%s" % [len(nonimagepageslist), "nonimage"]

		else:
			fetchednonimagedataobject = nonimagepage
		pt = var2str({"url":nonimagepage["url"], "byteOffset":nonimagepage.get("byteOffset")})
		
	if fetcheddrawing == null and fetchednonimagedataobject == null and httprequest == null and len(paperdrawinglist) > 0:
		var paperdrawing = paperdrawinglist.pop_back()
		var fetchreporttype = ""
		if paperdrawing.xcresource.begins_with("res://"):
			fetcheddrawingfile = paperdrawing.xcresource
			fetcheddrawing = paperdrawing
			if not File.new().file_exists(fetcheddrawingfile):
				fetcheddrawingfile = "res://guimaterials/imagefilefailure.png"
			fetchreporttype = "res"
		elif paperdrawing.xcresource.begins_with("http"):
			fetcheddrawingfile = imgdir+getshortimagename(paperdrawing.xcresource, true, 12)
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
				fetchreporttype = "request"
			else:
				print("using cached image ", fetcheddrawingfile)
				fetcheddrawing = paperdrawing
				fetchreporttype = "cache"
		else:
			fetcheddrawingfile = "res://guimaterials/imagefilefailure.png"
			fetchreporttype = "fail"
		pt = var2str(httprequest)
		imagesystemreportslabel.text = "%d-%s" % [len(paperdrawinglist), fetchreporttype]

	elif fetcheddrawing != null and not imageloadingthreadoperating:
		imageloadingthreadmutex.lock()
		assert(imageloadingthreaddrawingfile == null and imageloadingthreadloadedimagetexture == null)
		imageloadingthreaddrawingfile = fetcheddrawingfile
		imageloadingthreadmutex.unlock()
		imageloadingthreadoperating = true
		imageloadingthreadsemaphore.post()
		pt = "semaphore thread"

	elif fetcheddrawing != null:
		imageloadingthreadmutex.lock()
		assert(imageloadingthreaddrawingfile == null)
		var papertexture = imageloadingthreadloadedimagetexture
		imageloadingthreadloadedimagetexture = null
		imageloadingthreadmutex.unlock()
		if papertexture != null:
			imageloadingthreadoperating = false
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
		pt = "paptex"

	elif fetchednonimagedataobject != null:
		#print("FFFN ", fetchednonimagedataobject)
		if fetchednonimagedataobject.get("parsedumpcentreline") == "yes":
			get_node("/root/Spatial/ExecutingFeatures").parse3ddmpcentreline_execute(fetchednonimagedataobject["fetchednonimagedataobjectfile"], fetchednonimagedataobject["url"])
			
		elif "tree" in fetchednonimagedataobject:
			var htmltextfile = File.new()
			htmltextfile.open(fetchednonimagedataobject["fetchednonimagedataobjectfile"], File.READ)
			var htmltext = htmltextfile.get_as_text()
			htmltextfile.close()
			var llinks = [ ]
			if fetchednonimagedataobject.has("filetreeresource") and fetchednonimagedataobject["filetreeresource"].get("type") == "caddyfiles":
				var jres = parse_json(htmltext)
				if jres != null:
					for jr in jres:
						llinks.push_back(jr["name"] + ("/" if jr.get("is_dir") else ""))
			else:
				for m in listregex.search_all(htmltext):
					var lk = m.get_string(1)
					if not lk.begins_with("."):
						lk = lk.replace("&amp;", "&")
						llinks.push_back(lk)
			get_node("/root/Spatial/PlanViewSystem").openlinklistpage(fetchednonimagedataobject["item"], llinks)

		elif "callbackobject" in fetchednonimagedataobject:
			var f = File.new()
			f.open(fetchednonimagedataobject["fetchednonimagedataobjectfile"], File.READ)
			if "callbackfunction" in fetchednonimagedataobject:
				fetchednonimagedataobject["callbackobject"].call_deferred(fetchednonimagedataobject["callbackfunction"], f, fetchednonimagedataobject)
			elif "callbacksignal" in fetchednonimagedataobject:
				fetchednonimagedataobject["callbackobject"].emit_signal(fetchednonimagedataobject["callbacksignal"], f)
		
		fetchednonimagedataobject = null

	elif httprequest != null:
		httprequestduration += delta

	else:
		set_process(false)
	var dt = OS.get_ticks_msec() - t0
	if dt > 50:
		print("Long image system process ", dt, " ", pt)


func fetchunrolltree(fileviewtree, item, url, filetreeresource):
	var nonimagedataobject = { "url":url, "tree":fileviewtree, "item":item }
	if filetreeresource != null:
		nonimagedataobject["filetreeresource"] = filetreeresource
		if filetreeresource.get("type") == "caddyfiles":
			nonimagedataobject["headers"] = [ "accept: application/json" ]
	nonimagepageslist.append(nonimagedataobject)
	set_process(true)

func fetchrequesturl(nonimagedataobject):
	var url = nonimagedataobject["url"]
	if url.substr(0,4) == "http":
		print("fetchrequesturl ", url, " ", nonimagedataobject.get("byteOffset"), " ", nonimagedataobject.get("byteSize"))
		nonimagepageslist.append(nonimagedataobject)
		set_process(true)
	else:
		var f = File.new()
		f.open(url, File.READ)
		if nonimagedataobject.has("byteOffset"):
			f.seek(nonimagedataobject["byteOffset"])
		if "callbackfunction" in nonimagedataobject:
			nonimagedataobject["callbackobject"].call_deferred(nonimagedataobject["callbackfunction"], f, nonimagedataobject)
		elif "callbacksignal" in nonimagedataobject:
			yield(get_tree(), "idle_frame")
			nonimagedataobject["callbackobject"].emit_signal(nonimagedataobject["callbacksignal"], f)
		
func fetchpaperdrawing(paperdrawing):
	paperdrawinglist.push_back(paperdrawing)
	set_process(true)
	
func shuffleimagetotopoflist(paperdrawing):
	var fi = -1
	for i in range(len(paperdrawinglist)):
		if paperdrawinglist[i] == paperdrawing:
			fi = i
	if fi != -1:
		print("shuffling from ", fi, " in list ", len(paperdrawinglist))
		paperdrawinglist[fi] = paperdrawinglist[-1]
		paperdrawinglist[-1] = paperdrawing
	else:
		print("image not in paperdrawinglist queue")
