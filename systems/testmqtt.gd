extends Node

var possibleusernames = ["Alice", "Beth", "Cath", "Dan", "Earl", "Fred", "George", "Harry", "Ivan", "John", "Kevin", "Larry", "Martin", "Oliver", "Peter", "Quentin", "Robert", "Samuel", "Thomas", "Ulrik", "Victor", "Wayne", "Xavier", "Youngs", "Zephir"]
var topicstatus = ""
var randomplayername = ""

func received_mqtt(topic, msg):
	print("received_mqtt ", [topic, msg])

func on_broker_disconnect():
	print("broker_mqtt disconnect")
	topicstatus = ""
	
func on_broker_connect():
	print("broker_mqtt connect")

func _ready():
	$MQTT.server = "mosquitto.doesliverpool.xyz"
	#$MQTT.server = "10.0.100.1"
	$MQTT.connect("received_message", self, "received_mqtt")
	$MQTT.connect("broker_connected", self, "on_broker_connect")
	$MQTT.connect("broker_disconnected", self, "on_broker_disconnect")
	randomize()
	$MQTT.client_id = "s%d" % randi()
	
	randomplayername = possibleusernames[randi()%len(possibleusernames)]
	$MQTT.set_process(false)
	
	
func mqttupdatenetstatus():
	return
	
	var selfSpatial = get_node("/root/Spatial")
	var playerplatform = selfSpatial.playerMe.playerplatform
	var ltopicstatus = "tunnelvrv/%s/%s/%s/netstatus" % [$MQTT.client_id, playerplatform, randomplayername]
	if ltopicstatus != topicstatus:
		if topicstatus != "":
			$MQTT.disconnect_from_server()
			yield(get_tree(), "idle_frame")
		topicstatus = ltopicstatus
		$MQTT.set_last_will(topicstatus, "", true)
		if not yield($MQTT.connect_to_server(), "completed"):
			print("Failed to connect to mqtt broker")
			return
	var tunnelvrstatus = { }
	var guipanel3d = selfSpatial.get_node("GuiSystem/GUIPanel3D")
	tunnelvrstatus["ipnumber"] = selfSpatial.hostipnumber
	tunnelvrstatus["portnumber"] = selfSpatial.hostportnumber
	if guipanel3d.networkedmultiplayerenetserver != null or guipanel3d.websocketserver != null:
		tunnelvrstatus["state"] = "server"
	elif guipanel3d.networkedmultiplayerenetclient != null or guipanel3d.websocketclient != null:
		tunnelvrstatus["state"] = "client"
	else:
		tunnelvrstatus["state"] = "unconnected"
	tunnelvrstatus["sketchname"] = selfSpatial.get_node("SketchSystem").sketchname
	tunnelvrstatus["playermqttids"] = [ ]
	for player in selfSpatial.get_node("Players").get_children():
		if player != selfSpatial.playerMe:
			tunnelvrstatus["playermqttids"].push_back(player.playermqttid)
	$MQTT.publish(topicstatus, to_json(tunnelvrstatus), true)

func fpsbounce(mfpsbounce):
	$MQTT.publish(topicstatus+"/fpsbounce", mfpsbounce)

