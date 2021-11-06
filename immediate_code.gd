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
	var t = Transform2D()
	t = t.translated(Vector2(8, 9))
	t = t.scaled(Vector2(0.05, 1))
	print(t, t.affine_inverse())
	var p = Vector2(10, 20)
	var q = t.xform(p)
	var p1 = t.affine_inverse().xform(q)
	print(p, q, p1)
	
