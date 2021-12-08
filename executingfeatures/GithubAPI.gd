extends Node

var resourcesinformationfile = "user://resources.json"
var resourcesinformationfileBAK = "user://resources.json-bak"
var riattributes = null

var ghdirectory = "user://githubcache"
var ghattributes = null  # {"apiurl":"api.github.com", "owner":"goatchurchprime", "repo":"abdulsdiodedisaster", "path":"abdulsdiodedisaster", "token":"see https://github.com/settings/tokens"}
var ghcurrentname = ""
var ghcurrentsha = ""
var ghfetcheddatafile = ghdirectory+"/recgithubfile.res"
var ghattributesfile = ghdirectory+"/attributes.json"
var httpghapi = HTTPClient.new()

func saveresourcesinformationfile():
	var rijsonbak = File.new()
	rijsonbak.open(resourcesinformationfileBAK, File.WRITE)
	rijsonbak.store_string(JSON.print(riattributes, "  ", true))
	rijsonbak.close()
	var rijsondir = Directory.new()
	rijsondir.rename(resourcesinformationfileBAK, resourcesinformationfile)
			
func _ready():
	var rijson = File.new()
	if rijson.file_exists(resourcesinformationfile):
		rijson.open(resourcesinformationfile, File.READ)
		riattributes = parse_json(rijson.get_as_text())
	if true or riattributes == null:
		riattributes = { "playername":"player%d"%randi() }
		var resourcedefs = { "local":    { "name":"local", "type":"localfiles", "path":"cavefiles" }, 
							 "cavereg1": { "name":"cavereg1", "type":"svnfiles", "url":"http://cave-registry.org.uk/svn/", "path":"NorthernEngland" },
							 "caddyg":   { "name":"caddyg", "type":"caddyfiles", "url":"http://godot.doesliverpool.xyz:8000/", "path":"" },
							 "ghfiles":  { "name":"ghfiles", "type":"githubapi", "apiurl":"api.github.com", "owner":"goatchurchprime", "repo":"tunnelvr_cave_data", "path":"cavedata/firstarea"}
						   }
		riattributes["resourcedefs"] = resourcedefs
		saveresourcesinformationfile()
		
			
func Yinitclient():
	if ghattributes == null:
		var dir = Directory.new()
		if not dir.dir_exists(ghdirectory):
			dir.make_dir(ghdirectory)

		var ghjson = File.new()
		ghjson.open(ghattributesfile, File.READ)
		ghattributes = parse_json(ghjson.get_as_text())
		ghjson.close()
		if ghattributes == null:
			ghattributes = parse_json('{"apiurl":"api.github.com", "owner":"goatchurchprime", "repo":"tunnelvr_cave_data", "path":"cavedata/firstarea", "token":"see https://github.com/settings/tokens"}')

	yield(Engine.get_main_loop(), "idle_frame")
	if httpghapi.get_status() != HTTPClient.STATUS_CONNECTED:
		var e = httpghapi.connect_to_host(ghattributes["apiurl"], -1, true)
		while httpghapi.get_status() == HTTPClient.STATUS_CONNECTING or httpghapi.get_status() == HTTPClient.STATUS_RESOLVING:
			httpghapi.poll()
			yield(Engine.get_main_loop(), "idle_frame")


func Yghapicall(method, rpath, body):
	yield(Yinitclient(), "completed")
	var http = httpghapi
	var headers = [ "User-Agent: TunnelVR/0.7 (Godot)", 
					"Accept: application/vnd.github.v3+json", 
					"Authorization: token "+ghattributes["token"] ]
	var err = http.request(method, rpath, headers, body) 
	if err != OK:
		return null
	while http.get_status() == HTTPClient.STATUS_REQUESTING:
		http.poll()
		yield(Engine.get_main_loop(), "idle_frame")
	if not http.has_response() or http.get_response_code() > 202 or http.get_status() != HTTPClient.STATUS_BODY:
		print("bad response code: ", http.get_response_code())
		return null
	var rb = PoolByteArray()
	while http.get_status() == HTTPClient.STATUS_BODY:
		http.poll()
		var chunk = http.read_response_body_chunk()
		if chunk.size() == 0:
			yield(Engine.get_main_loop(), "idle_frame")
		else:
			rb = rb + chunk
	var rt = rb.get_string_from_ascii()
	return parse_json(rt)

func Ylistghfiles():
	yield(Yinitclient(), "completed")
	var rpath = "/repos/%s/%s/contents/%s" % [ ghattributes["owner"], ghattributes["repo"], ghattributes["path"] ]
	var d = yield(Yghapicall(HTTPClient.METHOD_GET, rpath, ""), "completed")
	var cfiles = [ ]
	for k in d:
		if k["type"] == "file":
			cfiles.push_back(k["name"])
	return cfiles

func Yfetchfile(cname):
	yield(Yinitclient(), "completed")
	var rpath = "/repos/%s/%s/contents/%s/%s" % [ ghattributes["owner"], ghattributes["repo"], ghattributes["path"], cname ]
	var d = yield(Yghapicall(HTTPClient.METHOD_GET, rpath, ""), "completed")
	if d.get("type") != "file" or d["encoding"] != "base64":
		return null
	ghcurrentname = d["name"]
	ghcurrentsha = d["sha"]
	var f = File.new()
	f.open(ghfetcheddatafile, File.WRITE)
	f.store_buffer(Marshalls.base64_to_raw(d["content"]))
	f.close()
	return ghfetcheddatafile

func Ycommitfile(cname, message):
	yield(Yinitclient(), "completed")
	var f = File.new()
	f.open(ghfetcheddatafile, File.READ)
	var contents = f.get_buffer(f.get_len())
	f.close()
	var rpath = "/repos/%s/%s/contents/%s/%s" % [ ghattributes["owner"], ghattributes["repo"], ghattributes["path"], cname ]
	var put_parameters = { "message":message, "content":Marshalls.raw_to_base64(contents) }
	if cname == ghcurrentname:
		put_parameters["sha"] = ghcurrentsha
	var d = yield(Yghapicall(HTTPClient.METHOD_PUT, rpath, to_json(put_parameters)), "completed")
	if d == null or not d.has("content") or d["content"].get("type") != "file":
		return null
	ghcurrentname = d["content"]["name"]
	ghcurrentsha = d["content"]["sha"]
	return ghfetcheddatafile


# Temporary testing code below
#
#
func addstufftofile():
	var ghrawfile = File.new()
	ghrawfile.open(ghfetcheddatafile, File.READ_WRITE)
	var h = ghrawfile.get_buffer(ghrawfile.get_len())
	ghrawfile.store_buffer(h)
	ghrawfile.store_buffer("\nding ding!\n".to_ascii())
	ghrawfile.close()
	
var message = "saywhat"
func D_input(event):	
	if event is InputEventKey and event.pressed and event.scancode == KEY_8:
		print(yield(Ylistghfiles(), "completed"))
		
	var ghfetchedname = "madebyapi.txt"
	if event is InputEventKey and event.pressed and event.scancode == KEY_9:
		print(yield(Yfetchfile("madebyapi.txt"), "completed"))
		
	if event is InputEventKey and event.pressed and event.scancode == KEY_K:
		addstufftofile()
		message = message + "-"
		print(yield(Ycommitfile("madebyapi.txt", message), "completed"))
