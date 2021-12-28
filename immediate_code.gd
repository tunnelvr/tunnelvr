tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******


func _run():
	var x = "h0"
	for i in range(50):
		if x[-1] >= 'a' and x[-1] < 'z':
			x = x.substr(0, len(x)-1)+char(ord(x[-1])+1)
		else:
			x = x + "a"
		print(x)	
