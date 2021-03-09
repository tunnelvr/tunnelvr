tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******
var regex = RegEx.new()
func _run():
	var f = File.new()
	f.open("res://surveyscans/wingform/Wing XYZ geometry.csv", File.READ)
	var k = [ ]
	for j in range(70):
		k.push_back(f.get_csv_line())
	var sections = [ ]
	for i in range(1, 60, 3):
		var pts = [ ]
		var z = float(k[2][i+1])
		for j in range(2, 70):
			assert (z == float(k[j][i+1]))
			pts.append(Vector2(float(k[j][i]), float(k[j][i+2])))
		sections.append(pts)
	print(sections)

