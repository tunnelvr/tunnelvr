tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******

func _run():
	var a = -361.0
	a = 49
	for i in range(20):
		a = a - (floor(a/360)*360)
		var x = rad2deg(Vector2(-1,-1).angle())
		if x > 180:
			x -= 180
		if abs(x + 360 - a) < abs(x + 180 - a):
			x += 360
		if abs(x + 180 - a) < abs(x - a):
			x += 180
		if abs(x - a) > 1:
			a += 10 if x > a else -10
		else:
			a = x
		print(x, " ", a)
		
