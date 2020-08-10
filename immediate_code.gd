tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******

const CentrelineStationNode = preload("res://nodescenes/StationNode.tscn")

func _ready():
	print("jjo")
	
func t(x=null):
	print("x=", x)

func _run():
	var x = IP.get_local_addresses()
	print("b" < "a")
	print(int("hifff")+2)
	t("ff")
