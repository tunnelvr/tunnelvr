tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******


func _run():
	var b = str2var(" Basis( -0.993549, -0.00992271, -0.113034, -0.010347, 0.999949, 0.0031679, 0.112995, 0.00431701, -0.993586 )")
	var b1 = str2var("Basis(0.007083, 0.000063, 1, -0.01082, 0.999941, 0.000014, -0.999916, -0.010821, 0.007083 )")
# ((0.007083, 0.000063, 1), (-0.01082, 0.999941, 0.000014), (-0.999916, -0.010821, 0.007083))0.01125
	print(b.orthonormalized().slerp(b1.orthonormalized(), 0.1))
	#print(b.get_rotation_quat())
	print(b.determinant())
	print(b1.determinant())
	
var zi = [ ]
var zi1 = [ 0.48, 0.66 ]


func _runjunk():
	var ij = -1
	var i1j = -1
	var zij0 = 0.0
	var zi1j0 = 0.0
	var zij1 = 1.0 if len(zi) == 0 else zi[0]
	var zi1j1 = 1.0 if len(zi1) == 0 else zi1[0]

	print("\nzi:", zi)
	print("zi1:", zi1)
	while true:
		assert(ij < len(zi) or i1j < len(zi1))
		var adv = 0
		if ij == len(zi):
			adv = 1
		elif i1j == len(zi1):
			adv = -1
		elif zi1j1 < zij1:
			if zi1j1 - zij0 < zij1 - zi1j1:
				adv = 1
		else:
			if zij1 - zi1j0 < zi1j1 - zij1:
				adv = -1

		if adv <= 0:
			ij += 1
			zij0 = zij1
			if ij != len(zi):
				zij1 = (1.0 if ij+1 == len(zi) else zi[ij+1]) 
		if adv >= 0:
			i1j += 1
			zi1j0 = zi1j1
			if i1j != len(zi1):
				zi1j1 = (1.0 if i1j+1 == len(zi1) else zi1[i1j+1]) 
		if ij == len(zi) and i1j == len(zi1):
			break
		print([zij0, zi1j0])
	print("done")
					
