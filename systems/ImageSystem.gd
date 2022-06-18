extends Node

var imgdir = "user://northernimages/"
var nonimagedir = "user://nonimagewebpages/"
var listregex = RegEx.new()

#var paperdrawinglist = [ ]
var nonimagepageslist = [ ]

var queuedrequests =  [ ]
var operatingrequests =  [ ]
var completedrequests = [ ]

var sparehttpclients = [ ]
const Nmaxsparehttpclients = 4

var imageloadingthreadmutex = Mutex.new()
var imageloadingthreadsemaphore = Semaphore.new()
var imageloadingthread = Thread.new()
var Nimageloadingrequests = 0

var imageloadingrequests = [ ]
var imageloadedrequests = [ ]

var imagethreadloadedflags = Texture.FLAG_MIPMAPS|Texture.FLAG_REPEAT # |Texture.FILTER

onready var imagesystemreportslabel = get_node("/root/Spatial/GuiSystem/GUIPanel3D/Viewport/GUI/Panel/ImageSystemReports")

var regexurl = RegEx.new()

# to convert PDFs nix-shell -p imagemagick and ghostscript, then 
# convert firstfloorplan.pdf -density 600 -geometry 200% -trim -background white -alpha remove -alpha off firstfloorplan.png
# density is still blurry because resizing is happening after rendering, so I had to use Gimp to load and export at a higher resolution

func imageloadingthread_function(userdata):
	print("imageloadingthread_function started")
	while true:
		imageloadingthreadsemaphore.wait()
		imageloadingthreadmutex.lock()
		var imagerequest = imageloadingrequests.pop_front()
		imageloadingthreadmutex.unlock()
		if imagerequest == null:
			break
		var limageloadingthreaddrawingfile = imagerequest["fetcheddrawingfile"]
		var t0 = OS.get_ticks_msec()
		var limageloadingthreadloadedimagetexture = ImageTexture.new()
		if not limageloadingthreaddrawingfile.begins_with("res://"):
			var limageloadingthreadloadedimage = Image.new()
			limageloadingthreadloadedimage.load(limageloadingthreaddrawingfile)
			var dt = OS.get_ticks_msec() - t0
			if dt > 100:
				print("thread loading ", limageloadingthreaddrawingfile, " took ", dt, " msecs")
			limageloadingthreadloadedimagetexture = ImageTexture.new()
			limageloadingthreadloadedimagetexture.create_from_image(limageloadingthreadloadedimage, imagethreadloadedflags)
		else:
			limageloadingthreadloadedimagetexture = ResourceLoader.load(limageloadingthreaddrawingfile)
		imagerequest["imageloadingthreadloadedimagetexture"] = limageloadingthreadloadedimagetexture
		imageloadingthreadmutex.lock()
		print(" ****yooooo ", limageloadingthreaddrawingfile)
		imageloadedrequests.push_back(imagerequest)
		imageloadingthreadmutex.unlock()

func _exit_tree():
	imageloadingthreadmutex.lock()
	imageloadingrequests.push_front(null)
	imageloadingthreadmutex.unlock()
	imageloadingthreadsemaphore.post()
	imageloadingthread.wait_to_finish()

func _ready():
	imageloadingthread.start(self, "imageloadingthread_function")
	listregex.compile('<li><a href="([^"]*)">')
	regexurl.compile("^(https?)://([^/:]*)(:\\d+)?(/.*)")

func clearallimageloadingactivity():
	operatingrequests.clear()
	completedrequests.clear()
	nonimagepageslist.clear()
	queuedrequests.clear()
	imageloadingrequests.clear()
	imageloadedrequests.clear()

func assignhttpclient(operatingrequest):
	assert (not operatingrequest.has("httpclient"))
	var urlcomponents = regexurl.search(operatingrequest["url"])
	if not urlcomponents:
		print("bad urlcomponents ", operatingrequest["url"])
		return false
	var host = urlcomponents.strings[2]
	var use_ssl = (urlcomponents.strings[1] == "https")
	var port = int(urlcomponents.strings[3])
	operatingrequest["urlkey"] = "%s %s %s"%[ host, port, use_ssl ]
	operatingrequest["urlpath"] = urlcomponents.strings[4]
	var httpclient = null
	for i in range(len(sparehttpclients)-1, -1, -1):
		if sparehttpclients[i]["urlkey"] == operatingrequest["urlkey"]:
			httpclient = sparehttpclients.pop_at(i)["httpclient"]
			break
	if httpclient != null:
		sparehttpclients.erase(operatingrequest["urlkey"])
		if httpclient.get_status() == HTTPClient.STATUS_CONNECTED:
			operatingrequest["httpclient"] = httpclient
			print(" reusing httpclient ", operatingrequest["url"])
			return true
	httpclient = HTTPClient.new()
	var e = httpclient.connect_to_host(host, (port if port else -1), use_ssl)
	if e != OK:
		print("not okay connect_to_host ", e)
		return false
	operatingrequest["httpclient"] = httpclient
	print(" new httpclient ", operatingrequest["urlkey"])
	return true

func storinghttpclient(operatingrequest):
	var httpclient = operatingrequest["httpclient"]
	operatingrequest.erase("httpclient")
	if httpclient.get_status() == HTTPClient.STATUS_CONNECTED:
		sparehttpclients.push_back({"urlkey":operatingrequest["urlkey"], "httpclient":httpclient})
		print(" storing httpclient ", operatingrequest["urlkey"])
	else:
		print(" dropping httpclient ", operatingrequest["urlkey"], " status ", httpclient.get_status())
	while len(sparehttpclients) >= Nmaxsparehttpclients:
		sparehttpclients.pop_front()

func http_request_poll(operatingrequest):
	var httpclient = operatingrequest["httpclient"]
	httpclient.poll()
	var httpclientstatus = httpclient.get_status()
	if httpclientstatus == HTTPClient.STATUS_DISCONNECTED:
		print(" disconnected httpclient ", operatingrequest["urlkey"])
		return -1
	elif httpclientstatus == HTTPClient.STATUS_RESOLVING or httpclientstatus == HTTPClient.STATUS_CONNECTING:
		return 0
	elif httpclientstatus == HTTPClient.STATUS_CANT_RESOLVE or httpclientstatus == HTTPClient.STATUS_CANT_CONNECT or httpclientstatus == HTTPClient.STATUS_CONNECTION_ERROR:
		print(" bad httpclientstatus ", operatingrequest["urlkey"], " ", httpclientstatus)
		return -1
	elif httpclientstatus == HTTPClient.STATUS_CONNECTED and not operatingrequest.has("partbody"):
		var err = httpclient.request(HTTPClient.METHOD_GET, operatingrequest["urlpath"], PoolStringArray(operatingrequest.get("headers", []))) 
		if err == OK:
			print(" httprequest made to ", operatingrequest["urlpath"])
			operatingrequest["partbody"] = PoolByteArray()
			return 0
		print("bad httpclient.request ", err)
		return -1
	elif httpclientstatus == HTTPClient.STATUS_REQUESTING:
		return 0
	elif httpclientstatus == HTTPClient.STATUS_BODY:
		var chunk = httpclient.read_response_body_chunk()
		if chunk.size() != 0:
			operatingrequest["partbody"] = operatingrequest["partbody"] + chunk
			#print("httpclient Chunk size ", chunk.size(), " ", len(operatingrequest["partbody"]), " ", operatingrequest["url"])
		return 0
	elif httpclientstatus == HTTPClient.STATUS_CONNECTED and operatingrequest.has("partbody"):
		var response_code = httpclient.get_response_code()
		if response_code == 200 or response_code == 206:
			var fout = File.new()
			var fname = operatingrequest["fetchednonimagedataobjectfile"] if operatingrequest.has("fetchednonimagedataobjectfile") else operatingrequest["fetcheddrawingfile"]
			fout.open(fname, File.WRITE)
			print("storing ", len(operatingrequest["partbody"]), " bytes to ", fname)
			fout.store_buffer(operatingrequest["partbody"])
			fout.close()
			operatingrequest.erase("partbody")
			storinghttpclient(operatingrequest)
			return 1
		else:
			operatingrequest.erase("partbody")
			print(" http response code bad ", response_code, " for ", operatingrequest)
			return -1
			
	else:
		print(" unknown httpclientstatus ", httpclientstatus)
		return -1
		

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


const Nmaxoperatingrequests = 2
func _process(delta):
	if len(operatingrequests) != 0:
		for i in range(len(operatingrequests)-1, -1, -1):
			var operatingrequest = operatingrequests[i]
			if http_request_poll(operatingrequest) != 0:
				operatingrequests.remove(i)
				completedrequests.push_back(operatingrequest)
	while len(queuedrequests) != 0 and len(operatingrequests) < Nmaxoperatingrequests:
		var operatingrequest = queuedrequests.pop_back()
		assignhttpclient(operatingrequest)
		operatingrequests.push_back(operatingrequest)
			
	var t0 = OS.get_ticks_msec()
	var Dpt = ""
	if len(completedrequests) == 0 and len(operatingrequests) == 0 and len(nonimagepageslist) > 0:
		var nonimagepage = nonimagepageslist.pop_front()
		nonimagepage["fetchednonimagedataobjectfile"] = nonimagedir + \
			getshortimagename(nonimagepage["url"], true, 
							  (10 if nonimagepage.has("byteOffset") else 20), 
							  nonimagepage)
		if not File.new().file_exists(nonimagepage["fetchednonimagedataobjectfile"]) or nonimagepage.get("donotusecache"):
			if not Directory.new().dir_exists(nonimagedir):
				var err = Directory.new().make_dir(nonimagedir)
				print("Making directory ", nonimagedir, " err code: ", err)
			var operatingrequest = nonimagepage
			var headers = operatingrequest.get("headers", [])
			if nonimagepage.has("byteOffset"):
				headers.push_back("Range: bytes=%d-%d" % [nonimagepage["byteOffset"], nonimagepage["byteOffset"]+nonimagepage["byteSize"]-1])
			operatingrequest["headers"] = headers
			imagesystemreportslabel.text = "%d-%s" % [len(nonimagepageslist), "nonimage"]
			assignhttpclient(operatingrequest)
			operatingrequests.push_back(operatingrequest)
		else:
			completedrequests.push_back(nonimagepage)
		Dpt = var2str({"url":nonimagepage["url"], "byteOffset":nonimagepage.get("byteOffset")})
		

	if Nimageloadingrequests != 0:
		imageloadingthreadmutex.lock()
		var imageloadedrequest = imageloadedrequests.pop_front() if len(imageloadedrequests) != 0 else null
		imageloadingthreadmutex.unlock()
		if imageloadedrequests != null:
			var papertexture = imageloadedrequest["imageloadingthreadloadedimagetexture"]
			Nimageloadingrequests -= 1
			if papertexture.get_width() != 0:
				var fetcheddrawing = imageloadedrequest["paperdrawing"]
				var fetcheddrawingmaterial = fetcheddrawing.get_node("XCdrawingplane/CollisionShape/MeshInstance").get_surface_material(0)
				fetcheddrawingmaterial.set_shader_param("texture_albedo", papertexture)
				var previmgheightwidthratio = fetcheddrawing.imgheightwidthratio
				fetcheddrawing.imgheightwidthratio = papertexture.get_height()*1.0/papertexture.get_width()
				if previmgheightwidthratio == 0:
					correctdefaultimgtrimtofull(fetcheddrawing)				
				if fetcheddrawing.imgwidth != 0:
					fetcheddrawing.applytrimmedpaperuvscale()
					
			else:
				print(imageloadedrequest["fetcheddrawingfile"], "   has zero width, deleting if user://")
				if imageloadedrequest["fetcheddrawingfile"].begins_with("user://"):
					Directory.new().remove(imageloadedrequest["fetcheddrawingfile"])
		Dpt = "paptex"



	var completedrequest = completedrequests.pop_front() if len(completedrequests) != null else null
	if completedrequest != null and "paperdrawing" in completedrequest:
		imageloadingthreadmutex.lock()
		imageloadingrequests.push_back(completedrequest)
		completedrequest = null
		imageloadingthreadmutex.unlock()
		Nimageloadingrequests += 1
		imageloadingthreadsemaphore.post()
		Dpt = "semaphore thread"


	elif completedrequest != null:
		var fetchednonimagedataobject = completedrequest
		#print("FFFN ", fetchednonimagedataobject)
		if fetchednonimagedataobject.get("parsedumpcentreline") == "yes":
			get_node("/root/Spatial/ExecutingFeatures").parse3ddmpcentreline_execute(fetchednonimagedataobject["fetchednonimagedataobjectfile"], fetchednonimagedataobject["url"])
			
		elif "tree" in fetchednonimagedataobject:
			var htmltextfile = File.new()
			htmltextfile.open(fetchednonimagedataobject["fetchednonimagedataobjectfile"], File.READ)
			var htmltext = htmltextfile.get_as_text()
			htmltextfile.close()
			var llinks = [ ]
			if fetchednonimagedataobject.has("filetreeresource"):
				if fetchednonimagedataobject["filetreeresource"].get("type") == "caddyfiles":
					var jres = parse_json(htmltext)
					if jres != null:
						for jr in jres:
							llinks.push_back(jr["name"] + ("/" if jr.get("is_dir") else ""))
				elif fetchednonimagedataobject["filetreeresource"].get("type") == "githubapi":
					var jres = parse_json(htmltext)
					if jres != null:
						for jr in jres:
							llinks.push_back(jr["name"] + ("/" if jr.get("type") == "dir" else ""))
				elif fetchednonimagedataobject["filetreeresource"].get("type") == "svnfiles":
					for m in listregex.search_all(htmltext):
						var lk = m.get_string(1)
						if not lk.begins_with("."):
							lk = lk.replace("&amp;", "&")
							llinks.push_back(lk)

			else:
				for m in listregex.search_all(htmltext):   # svnfiles type bydefault
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

	if len(operatingrequests) == 0 and len(completedrequests) != 0 and Nimageloadingrequests == 0:
		set_process(false)
		
	var dt = OS.get_ticks_msec() - t0
	if dt > 50:
		print("Long image system process ", dt, " ", Dpt)


func fetchunrolltree(fileviewtree, item, url, filetreeresource):
	var nonimagedataobject = { "url":url, "tree":fileviewtree, "item":item, "donotusecache":true }
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
	print(" ****yaaaaaa ", paperdrawing.xcresource)
	var fetcheddrawingfile = "res://guimaterials/imagefilefailure.png"
	if paperdrawing.xcresource.begins_with("http"):
		fetcheddrawingfile = imgdir+getshortimagename(paperdrawing.xcresource, true, 12)
		if not File.new().file_exists(fetcheddrawingfile):
			if not Directory.new().dir_exists(imgdir):
				var err = Directory.new().make_dir(imgdir)
				print("Making directory ", imgdir, " err code: ", err)
			var queuedrequest = { "paperdrawing":paperdrawing, 
								  "objectname":paperdrawing.get_name(), 
								  "fetcheddrawingfile":fetcheddrawingfile, 
								  "url":paperdrawing.xcresource }
			queuedrequests.push_back(queuedrequest)
			return
		else:
			print("using cached image ", fetcheddrawingfile)
	elif paperdrawing.xcresource.begins_with("res://"):
		fetcheddrawingfile = paperdrawing.xcresource
	completedrequests.push_back({ "paperdrawing":paperdrawing, 
								  "fetcheddrawingfile":fetcheddrawingfile })
	set_process(true)
	
	
func shuffleimagetotopoflist(paperdrawing):
	var fi = -1
	for i in range(len(queuedrequests)):
		var queuedrequest = queuedrequests[i]
		if "paperdrawing" in queuedrequest:
			if queuedrequest[i]["paperdrawing"] == paperdrawing:
				fi = i
	if fi != -1:
		print("shuffling from ", fi, " in list ", len(queuedrequests))
		var queuedrequest = queuedrequests[-1]
		queuedrequests[fi] = queuedrequests[-1]
		queuedrequests[-1] = queuedrequest
	else:
		print("image not in queuedrequests list")
