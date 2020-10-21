extends Node


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	set_process(false)
	return
	$mqttnode.connect_to_server()
	$mqttnode.subscribe("doesliverpool/coffeedesc")
	$mqttnode.connect("received_message", self, "received_message")
	
var msg = ""

func received_message(topic, message):
	print("RRRRR: ", topic, ": ", message)
	msg = "DoESLiverpool "+message
	
var d = 5
var d2 = 1
func _process(delta):
	d -= delta
	if d < 0:
		$mqttnode.publish("hi", "there")
		d = 5
	d2 =- delta
	if d2 < 0:
		$mqttnode.check_msg()
		d2 = 1
