extends Node

var ghdirectory = "user://githubcache"
var ghattributes = null  # {"apiurl":"api.github.com", "owner":"goatchurchprime", "repo":"abdulsdiodedisaster", "path":"abdulsdiodedisaster", "token":"see https://github.com/settings/tokens"}
var ghcurrentname = ""
var ghcurrentsha = ""
var ghfetcheddatafile = ghdirectory+"/recgithubfile.res"
var httpghapi = HTTPClient.new()

func Yinitclient():
	if ghattributes == null:
		var dir = Directory.new()
		if not dir.dir_exists(ghdirectory):
			dir.make_dir(ghdirectory)

		var ghjson = File.new()
		ghjson.open(ghdirectory+"/attributes.json", File.READ)
		ghattributes = parse_json(ghjson.get_as_text())
		ghjson.close()
		if ghattributes == null:
			ghattributes = '{"apiurl":"api.github.com", "owner":"goatchurchprime", "repo":"abdulsdiodedisaster", "path":"abdulsdiodedisaster", "token":"see https://github.com/settings/tokens"}'

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
