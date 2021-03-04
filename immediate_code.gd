tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******
var regex = RegEx.new()
func _run():
	regex.compile('(?i)^([a-z0-9.\\-_]+)\\s*$')
	var x = "k-0_kl \n "
	print([x])
	x = regex.search(x)
	print(x == null)
	print(x.get_string(1))
	print("s*sdfsdf".lstrip("*"))

	var some_string = "One,Two,Three,Four"
	var some_array = some_string.rsplit(",", true, 1)
	print(some_array.size()) # Prints 2
	print(some_array[0]) # Prints "Four"
	print(some_array[1]) # Prints "Three,Two,One"
	
	var g = "sdfsdf1.res"
	print(g, "  ", g.substr(0, len(g)-4))

