tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******

func D_run():
	var a = PoolStringArray()
	a.push_back("d")
	if a:
		print("hji there")


func _run():
	var a = [2,3,4]
	for i in range(1, len(a)):
		print(i, " ", a[i])
