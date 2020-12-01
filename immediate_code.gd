tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******

func _run():
	var x = {2:Rect2(0,0,5,5)}
	x.clear()
	print(x)
	
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
					
