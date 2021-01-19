tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******
	
	
func _run():
	var a = [10,20,30,40,50]
	var i = a.find(10)
	if i != 0:
		a = a.slice(i,len(a)-1) + a.slice(0,i-1)
	print(a)
