tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******


func thing(x):
	var v = Timer.new()
	v.one_shot = true
	v.wait_time = 3.0
	v.start()
	#yield(v, "timeout")
	print("kkkkk ", x)

signal sthing(x)

func _run():
	print(thing(99))
		
