tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******

# rotationtoalign(a, b)*a is parallel to b
func rotationtoalign(a, b):
	var c = a.cross(b)
	var d = a.dot(b)
	var clength = c.length()
	var abl = a.length()*b.length()
	if abl == 0.0 or clength == 0.0:
		return Basis()
	var sinrot = clength/(a.length()*b.length())
	var rotang = asin(sinrot)
	if d < 0.0:
		if rotang > 0.0:
			rotang = PI-rotang
		else:
			rotang = -(PI-(-rotang))
	var res = Basis(c/clength, rotang)
	var l = res.xform(a)*b.length()
	print(c, b, l)
	return res

func _run():
	var x = Vector3(-0.027, 0.003, -0.027).normalized()
#	rotationtoalign(Vector3(0,0,1), Vector3(-0.027, 0.003, -0.027))
#	rotationtoalign(Vector3(0,0,1), x)
	rotationtoalign(Vector3(0,0,1), Vector3(-1,0,-1))
	rotationtoalign(Vector3(0,0,1), Vector3(-1,0,1))
		
