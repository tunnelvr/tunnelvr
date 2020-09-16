extends Node

const defaultfloordrawing = "http://cave-registry.org.uk/svn/NorthernEngland/ThreeCountiesArea/rawscans/Ireby/DukeStResurvey-drawnup-p3.jpg"
const defaultfloordrawingres = "res://surveyscans/DukeStResurvey-drawnup-p3.jpg"

var imgdir = "user://northernimages/"
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

func getshortimagename(xcresource, withextension):
	var fname = xcresource.substr(xcresource.find_last("/")+1)
	var ext = xcresource.get_extension()
	if ext != null:  
		ext = "."+ext
	fname = fname.get_basename()
	fname = fname.replace(".", "").replace("@", "").replace("%", "")
	var md5name = xcresource.md5_text().substr(0, 6)
	if len(fname) > 8:
		fname = fname.substr(0,4)+md5name+fname.substr(len(fname)-4)
	else:
		fname = fname+md5name
	return fname+ext if withextension else fname


var paperdrawinglist = [ ]

var imagefetchingcountdowntimer = 0.0
var imagefetchingcountdowntime = 0.15
var fetcheddrawing = null
var httprequest = null
var httprequestduration = 0.0
var fetcheddrawingfile = null

func _http_request_completed(result, response_code, headers, body, lhttprequest, paperdrawing):
	assert (lhttprequest == httprequest)
	lhttprequest.queue_free()
	if response_code == 200:
		fetcheddrawing = paperdrawing
	else:
		print("http response code bad ", response_code, " for ", paperdrawing.get_name())
	httprequest = null
	
func _process(delta):
	if imagefetchingcountdowntimer > 0.0:
		imagefetchingcountdowntimer -= delta
	elif fetcheddrawing != null:
		var img = Image.new()
		print("FFF", [fetcheddrawing, fetcheddrawingfile])
		img.load(fetcheddrawingfile)
		var papertexture = ImageTexture.new()
		papertexture.create_from_image(img)
		fetcheddrawing.get_node("XCdrawingplane/CollisionShape/MeshInstance").get_surface_material(0).albedo_texture = papertexture
		if papertexture.get_width() != 0:
			fetcheddrawing.get_node("XCdrawingplane").scale.y = fetcheddrawing.get_node("XCdrawingplane").scale.x*papertexture.get_height()/papertexture.get_width()
		else:
			print(fetcheddrawing.get_name(), "   has zero width ")
		fetcheddrawing = null
	elif httprequest != null:
		httprequestduration += delta
	elif len(paperdrawinglist) > 0:
		var paperdrawing = paperdrawinglist.pop_front()
		fetcheddrawingfile = imgdir+getshortimagename(paperdrawing.xcresource, true)
		print([paperdrawing.xcresource, defaultfloordrawing])
		print([1, fetcheddrawingfile])
		#if paperdrawing.xcresource == defaultfloordrawing:
		#	fetcheddrawingfile = defaultfloordrawingres
		if not File.new().file_exists(fetcheddrawingfile):
			if not Directory.new().dir_exists(imgdir):
				Directory.new().make_dir(imgdir)
			httprequest = HTTPRequest.new()
			add_child(httprequest)
			httprequest.connect("request_completed", self, "_http_request_completed", [httprequest, paperdrawing])
			httprequest.download_file = fetcheddrawingfile
			httprequest.request(paperdrawing.xcresource)
			httprequestduration = 0.0
		else:
			fetcheddrawing = paperdrawing
	else:
		set_process(false)

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
		paperdrawinglist.append(paperdrawing)
		get_node("/root/Spatial/SketchSystem").sharexcdrawingovernetwork(paperdrawing)
		fetchpaperdrawing(paperdrawing)



func _input(event):
	if event is InputEventKey and event.pressed and event.scancode == KEY_V:
		fetchimportpapers()
