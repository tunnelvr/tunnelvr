extends Node

export var websocket_url_outgoing = "ws://sensorcity.io:1880/godotws_outgoing"
export var websocket_url_incoming = "ws://sensorcity.io:1880/godotws_incoming"

var client_outgoing = WebSocketClient.new()
var client_incoming = WebSocketClient.new()  # (websockets on node-red are only oneway)

func _ready():
	client_outgoing.connect("connection_closed", self, "closed_outgoing")
	client_outgoing.connect("connection_error", self, "closed_outgoing")
	client_outgoing.connect("connection_established", self, "connected_outgoing")
	#client_outgoing.connect("data_received", self, "_on_data")

	client_incoming.connect("connection_closed", self, "closed_incoming")
	client_incoming.connect("connection_error", self, "closed_incoming")
	client_incoming.connect("connection_established", self, "connected_incoming")
	client_incoming.connect("data_received", self, "on_data_incoming")
	set_process(false)

	
func connectws():
	var err_outgoing = client_outgoing.connect_to_url(websocket_url_outgoing)
	var err_incoming = client_incoming.connect_to_url(websocket_url_incoming)
	print(websocket_url_outgoing, err_outgoing)
	print(websocket_url_incoming, err_incoming)
	if err_outgoing == OK and err_incoming == OK:
		set_process(true)
	else:
		print("Unable to connect", err_outgoing, err_incoming)
		
func closed_outgoing(was_clean = false):
	print("Closed outgoing: ", was_clean)
	set_process(false)
func closed_incoming(was_clean = false):
	print("Closed incoming: ", was_clean)
	set_process(false)

func connected_outgoing(proto = ""):
	print("Connected outgoing with protocol: ", proto)
func connected_incoming(proto = ""):
	print("Connected incoming with protocol: ", proto)

func senddata_outgoing(data): 
	client_outgoing.get_peer(1).put_packet(data)
	#"Test packet".to_utf8()
	
func on_data_incoming():
	var data = client_incoming.get_peer(1).get_packet()
	print("Got data froddm server: ", len(data))
	#if len(data) < 100:
	#	print("Got data bfrom server: ", data.get_string_from_utf8())
	
var heartbeattimeout = 1.0	
func _process(delta):
	client_outgoing.poll()
	client_incoming.poll()
	heartbeattimeout -= delta
	if heartbeattimeout <= 0.0:
		senddata_outgoing("beat".to_utf8())
		heartbeattimeout = 1.0

func _input(event):
	if event is InputEventKey and event.pressed and event.scancode == KEY_P:
		connectws()
