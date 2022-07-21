extends Node

var resourcesinformationfile = "user://resources.json"
var resourcesinformationfileBAK = "user://resources.json-bak"
var riattributes = { }

var ghdirectory = "user://githubcache"
var ghattributes = { }
var ghcurrentname = ""
var ghcurrentsha = ""
var ghfetcheddatafile = ghdirectory+"/recgithubfile.res"
var httpghapi = HTTPClient.new()

func saveresourcesinformationfile():
	var rijsonbak = File.new()
	rijsonbak.open(resourcesinformationfileBAK, File.WRITE)
	rijsonbak.store_string(JSON.print(riattributes, "  ", true))
	rijsonbak.close()
	var rijsondir = Directory.new()
	rijsondir.rename(resourcesinformationfileBAK, resourcesinformationfile)
			
func resources_readycallloadinfo():
	var rijson = File.new()
	if rijson.file_exists(resourcesinformationfile):
		rijson.open(resourcesinformationfile, File.READ)
		riattributes = parse_json(rijson.get_as_text())
	if not riattributes:
		riattributes = { }
		randomize()
		var possiblehumannames = get_node("/root/Spatial/MQTTExperiment").possibleusernames
		var randomplayerhumanname = possiblehumannames[randi()%len(possiblehumannames)]
		var resourcedefs = { "local":    { "name":"local", "type":"localfiles", "path":"user://cavefiles/", "playername":randomplayerhumanname }, 
							 "cavereg1": { "name":"cavereg1", "type":"svnfiles", "url":"http://cave-registry.org.uk/svn/", "path":"NorthernEngland" },
							 "caddyg":   { "name":"caddyg", "type":"caddyfiles", "url":"http://godot.doesliverpool.xyz:8000/", "path":"" },
							 "ghfiles":  { "name":"ghfiles", "type":"githubapi", "apiurl":"api.github.com", "owner":"goatchurchprime", "repo":"tunnelvr_cave_data", "path":"cavedata/firstarea" }
						   }
		riattributes["resourcedefs"] = resourcedefs
		saveresourcesinformationfile()
	var playerMe = get_node("/root/Spatial").playerMe
	playerMe.playerhumanname = riattributes.get("resourcedefs", {}).get("local", {}).get("playername", "")
		
	var dir = Directory.new()
	if not dir.dir_exists(ghdirectory):
		dir.make_dir(ghdirectory)
			
func Yinitclient():
	yield(Engine.get_main_loop(), "idle_frame")
	if ghattributes.get("type") == "githubapi":
		if httpghapi.get_status() != HTTPClient.STATUS_CONNECTED:
			var e = httpghapi.connect_to_host(ghattributes["apiurl"], -1, true)
			if e == OK:
				while httpghapi.get_status() == HTTPClient.STATUS_CONNECTING or httpghapi.get_status() == HTTPClient.STATUS_RESOLVING:
					httpghapi.poll()
					yield(Engine.get_main_loop(), "idle_frame")
			else:
				print("Connection to host ", ghattributes["apiurl"], " failed err:", e)

func Ylistdircavefilelist():
	yield(Engine.get_main_loop(), "idle_frame")
	var cfiles = [ ]
	if ghattributes.get("type") == "localfiles":
		var dir = Directory.new()
		var cavefilesdir = ghattributes.get("path", "user://cavefiles")
		if not dir.dir_exists(cavefilesdir):
			var err = Directory.new().make_dir(cavefilesdir)
			print("Making directory ", cavefilesdir, " err code: ", err)
		var e = dir.open(cavefilesdir)
		if e == OK:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if file_name != "." and file_name != "..":
					assert (not dir.current_is_dir())
					if file_name.ends_with(".res"):
						var cname = file_name.substr(0, len(file_name)-4)
						cfiles.push_back(ghattributes["name"]+": "+cname)
				file_name = dir.get_next()
			return cfiles
		return ["Err: list local dir error"]

	elif ghattributes.get("type") == "githubapi":
		var mcfiles = yield(Ylistghfiles(), "completed")
		if mcfiles == null:
			return ["Err: githubapi listdir failure"]

		for mcfile in mcfiles:
			var matchesgha = (mcfile+".res" == ghcurrentname) and (mcfiles[mcfile] == ghcurrentsha)
			cfiles.push_back(ghattributes["name"]+": "+("#" if matchesgha else "")+mcfile)
		return cfiles

func Yloadcavefile(lghattributes, savegamefilename):
	yield(Engine.get_main_loop(), "idle_frame")
	var sketchsystem = get_node("/root/Spatial/SketchSystem")
	if lghattributes.get("type") == "localfiles":
		var cavefilesdir = lghattributes.get("path", "user://cavefiles").rstrip("/")
		var savegamefilenameU = cavefilesdir+"/"+savegamefilename+".res"
		if File.new().file_exists(savegamefilenameU):
			sketchsystem.call_deferred("loadsketchsystemL", savegamefilenameU)
			return true
	elif lghattributes.get("type") == "githubapi":
		assert (lghattributes["name"] == ghattributes["name"])
		if yield(Yfetchfile(savegamefilename+".res", ghfetcheddatafile), "completed"):
			sketchsystem.call_deferred("loadsketchsystemL", ghfetcheddatafile)
			return true
		else:
			print("Fetch failed")
	return false

func Ysavecavefile(savegamefilename, bfileisnew):
	var sketchsystem = get_node("/root/Spatial/SketchSystem")	
	yield(Engine.get_main_loop(), "idle_frame")

	if ghattributes.get("type") == "localfiles":
		var cavefilesdir = ghattributes.get("path", "user://cavefiles").rstrip("/")
		var savegamefilenameU = cavefilesdir+"/"+savegamefilename+".res"
		sketchsystem.savesketchsystem(savegamefilenameU)
		return "Saved locally"

	elif ghattributes.get("type") == "githubapi":
		var savegamefilenameU = savegamefilename + ".res"
		if not bfileisnew and savegamefilenameU != ghcurrentname:
			return "Mismatch name"
		elif not ghattributes.has("token"):
			return "Missing github API token"
		else:
			var playerMe = get_node("/root/Spatial").playerMe
			var message = "Saved by %s from %s" % [ playerMe.playerhumanname, playerMe.playerplatform ]
			sketchsystem.savesketchsystem(ghfetcheddatafile)
			var guipanel3d = get_node("/root/Spatial/GuiSystem/GUIPanel3D")
			guipanel3d.setpanellabeltext("Committing file")
			yield(Yinitclient(), "completed")
			var f = File.new()
			f.open(ghfetcheddatafile, File.READ)
			var jput_parameters = to_json({ "message":message, 
											"sha":"" if bfileisnew else ghcurrentsha,
											"content":Marshalls.raw_to_base64(f.get_buffer(f.get_len())) })
			f.close()
			var rpath = "/repos/%s/%s/contents/%s/%s" % [ ghattributes["owner"], ghattributes["repo"], ghattributes["path"], savegamefilenameU ]
			var d = yield(Yghapicall(HTTPClient.METHOD_PUT, rpath, jput_parameters), "completed")
			if d == null or not d.has("content") or d["content"].get("type") != "file":
				print("Ycommitfile fail ", d)
				return "Commit file fail"
			ghcurrentname = d["content"]["name"]
			ghcurrentsha = d["content"]["sha"]
			return "Commit success!!!"

	return "Ysavecavefile fail"


func Yghapicall(method, rpath, body):
	yield(Yinitclient(), "completed")
	var http = httpghapi
	var headers = [ "User-Agent: TunnelVR/0.7 (Godot)", 
					"Accept: application/vnd.github.v3+json" ] 
	if ghattributes.get("token"):
		headers.push_back("Authorization: token "+ghattributes["token"])
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
	var rpath = "/repos/%s/%s/contents/%s" % [ ghattributes["owner"], ghattributes["repo"], ghattributes["path"] ]
	var d = yield(Yghapicall(HTTPClient.METHOD_GET, rpath, ""), "completed")
	if d == null:
		return null
	var mcfiles = { }
	for k in d:
		if k["type"] == "file":
			var file_name = k["name"]
			if file_name.ends_with(".res"):
				var cname = file_name.substr(0, len(file_name)-4)
				mcfiles[cname] = k["sha"]
			else:
				print("skipping githubfile ", file_name)
	return mcfiles

# curl https://api.github.com/repos/goatchurchprime/tunnelvr_cave_data/contents/README.md
# GET https://api.github.com/repos/:owner/:repo/commits?path=FILE_PATH
#curl https://api.github.com/repos/goatchurchprime/tunnelvr_cave_data/commits?README.md
#GET https://api.github.com/repos/:owner/:repo/commits?path=FILE_PATH
#https://docs.github.com/en/rest/reference/repos#contents
#https://stackoverflow.com/questions/16700297/using-github-api-to-retrieve-all-versions-of-a-specific-file
# new github apikey "token": instructions at https://github.com/settings/tokens

func Yfetchfile(cname, lghfetcheddatafile):
	yield(Yinitclient(), "completed")
	var rpath = "/repos/%s/%s/contents/%s/%s" % [ ghattributes["owner"], ghattributes["repo"], ghattributes["path"], cname ]
	var d = yield(Yghapicall(HTTPClient.METHOD_GET, rpath, ""), "completed")
	if d == null or d.get("type") != "file" or d["encoding"] != "base64":
		print("Yfetchfile failed ", d)
		return false
	ghcurrentname = d["name"]
	ghcurrentsha = d["sha"]
	var f = File.new()
	f.open(lghfetcheddatafile, File.WRITE)
	f.store_buffer(Marshalls.base64_to_raw(d["content"]))
	f.close()
	return true

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
		print("Ycommitfile fail ", d)
		return null
	ghcurrentname = d["content"]["name"]
	ghcurrentsha = d["content"]["sha"]
	return ghfetcheddatafile

