tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******


func _run():
	var h = "https://raw.githubusercontent.com/goatchurchprime/abdulsdiodedisaster/master/junk/madebyapi.txt"
	var b = h.split("/", true, 3)
	print(b)
	assert(b[0] == "https:" and b[1] == "")
	print(b[2])
	print(b[3])
	print(null or PoolByteArray())
		
func DD_run():

	var http = HTTPClient.new()
	var e = http.connect_to_host("api.github.com", -1, true)
#https://github.com/goatchurchprime/abdulsdiodedisaster/blob/master/junk/madebyapi.txt
	print(e, " ", http.get_status())
	
	while http.get_status() == HTTPClient.STATUS_CONNECTING or http.get_status() == HTTPClient.STATUS_RESOLVING:
		http.poll()
		yield(Engine.get_main_loop(), "idle_frame")
		print(http.get_status())

	var headers = [
		"User-Agent: Pirulo/1.0 (Godot)",
		"Accept: */*"
	]

	var err = http.request(HTTPClient.METHOD_GET, "/repos/goatchurchprime/abdulsdiodedisaster/contents/junk", headers) # Request a page from the site (this one was chunked..)
	assert(err == OK) # Make sure all is OK.

	while http.get_status() == HTTPClient.STATUS_REQUESTING:
		http.poll()
		print("Requesting...")
		yield(Engine.get_main_loop(), "idle_frame")

	assert(http.get_status() == HTTPClient.STATUS_BODY or http.get_status() == HTTPClient.STATUS_CONNECTED) # Make sure request finished well.

	print("response? ", http.has_response()) # Site might not have a response.
	if http.has_response():
		headers = http.get_response_headers_as_dictionary() # Get response headers.
		print("code: ", http.get_response_code()) # Show response code.
		print("**headers:\\n", headers) # Show headers.

		# Getting the HTTP Body

		if http.is_response_chunked():
			print("Response is Chunked!")
		else:
			var bl = http.get_response_body_length()
			print("Response Length: ", bl)

		var rb = PoolByteArray() # Array that will hold the data.
		while http.get_status() == HTTPClient.STATUS_BODY:
			http.poll()
			# Get a chunk.
			var chunk = http.read_response_body_chunk()
			if chunk.size() == 0:
				yield(Engine.get_main_loop(), "idle_frae")
			else:
				rb = rb + chunk # Append to read buffer.

		print("bytes got: ", rb.size())
		var text = rb.get_string_from_ascii()
		print("Text: ", text)
		
		var d = parse_json(text)
		print(d)
		print(http.connection)
		
	
#		curl https://api.github.com/repos/goatchurchprime/abdulsdiodedisaster/contents/junk
#		/repos/{owner}/{repo}/contents/{path} <http://docs.github.com/en/rest/reference/repos#contents>`_
	
