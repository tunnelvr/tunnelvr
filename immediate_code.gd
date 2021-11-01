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
	var ip = 9
	var en = { "li":20, "lo":22, "hi":20, "ho":20}
	for i in range(11):
		var l = i*1.0/10
		print(l, " ", 1 - 4*pow(l-0.5, 2))
		
