tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******

# https://github.com/godotengine/godot/blob/fc481db1c3187688d54b5afdb7a1ebb3e4d506c2/core/math/basis.cpp#L774
func get_quat(m):
	var trace = m.elements[0][0] + m.elements[1][1] + m.elements[2][2]
	var temp = [ 0, 0, 0, 0]

	if (trace > 0.0):
		var s = sqrt(trace + 1.0)
		temp[3] = (s * 0.5)
		s = 0.5 / s

		temp[0] = ((m.elements[2][1] - m.elements[1][2]) * s);
		temp[1] = ((m.elements[0][2] - m.elements[2][0]) * s);
		temp[2] = ((m.elements[1][0] - m.elements[0][1]) * s);
	else:
		var i = (2 if m.elements[1][1] < m.elements[2][2] else 1)  \
					if m.elements[0][0] < m.elements[1][1] \
						else \
						(2 if m.elements[0][0] < m.elements[2][2] else 0);
		var j = (i + 1) % 3;
		var k = (i + 2) % 3;

		var s = sqrt(m.elements[i][i] - m.elements[j][j] - m.elements[k][k] + 1.0);
		temp[i] = s * 0.5;
		s = 0.5 / s;

		temp[3] = (m.elements[k][j] - m.elements[j][k]) * s;
		temp[j] = (m.elements[j][i] + m.elements[i][j]) * s;
		temp[k] = (m.elements[k][i] + m.elements[i][k]) * s;

	return temp


func _run():
	var trans = Transform(Basis(), Vector3(100,10,90))
	var d = Vector3(0.1,2,0.5)
	for i in range(301):
		var t1 = Transform(Basis(), -d)
		var t2 = Transform(Basis(), d)
		var rot = Transform().rotated(Vector3(0.0, -1, 0.0), deg2rad(22.5))
		#trans.origin += trans.basis.x*1.2
		trans = (trans*t2*rot*t1)
		#trans = (trans*t2*rot*t1).orthonormalized()
		if (i%50) == 0:
			print(i, " ", trans.basis.determinant())
	print(trans)
	print(trans.orthonormalized())
	#a.rotatesh
	#print(a.determinant())
	#print(y)
	#print(is_equal_approx(0.99998, 1))
	#var m = { "elements":[[a.x.x, a.x.y, a.x.z], [a.y.x, a.y.y, a.y.z], [a.z.x, a.z.y, a.z.z]] }
	#var q = get_quat(m)
	#print(q, q[0]*q[0] + q[1]*q[1] + q[2]*q[2] + q[3]*q[3])
	#print(Quat(b))
