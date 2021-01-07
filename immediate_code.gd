tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******
	
	
func _run():
	var a = Rect2(0,0,10,10)
	print(a.intersects(Rect2(-4.1,0,5,1)))	

