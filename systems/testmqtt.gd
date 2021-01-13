extends Node


# Called when the node enters the scene tree for the first time.
var uniqstring
var topicstem

func _ready():
	uniqstring = OS.get_unique_id().replace("{", "").split("-")[0].to_upper()
	print(uniqstring)
	topicstem = "tunnelvr/u%s/" % uniqstring
	$mqttnode.server = "mosquitto.doesliverpool.xyz"
	$mqttnode.client_id = "u"+uniqstring
	$mqttnode.connect("received_message", self, "received_message")
	if true:
		call_deferred("connectmqtt")
	else:
		print("disabling mqtt")

func mqttpublish(subtopic, payload):
	$mqttnode.publish(topicstem+subtopic, payload)
	
func connectmqtt():
	$mqttnode.set_last_will(topicstem+"status", "stopped", true)
	if yield($mqttnode.connect_to_server(), "completed"):
		$mqttnode.publish(topicstem+"status", "connected", true)
		print("subscribing to ", topicstem)
		$mqttnode.subscribe(topicstem+"cmd")
	else:
		print("mqtt failed to connect")

var msg = ""
func received_message(topic, message):
	print("MQTT RECEIVED: ", topic, ": ", message)
	msg = message
	
const checkmessageinterval = 0.4
var checkmessagetimer = checkmessageinterval
const framerateinterval = 1.1
var frameratetimer = framerateinterval
func _process(delta):
	checkmessagetimer -= delta
	if checkmessagetimer < 0:
		$mqttnode.check_msg()
		checkmessagetimer = checkmessageinterval
	frameratetimer -= delta
	if frameratetimer < 0:
		$mqttnode.publish(topicstem+"fps", String(Performance.get_monitor(Performance.TIME_FPS)))
		frameratetimer = framerateinterval
		
