tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******

func _run():
	var d = "res://surveyscans/LambTrap-drawnup-1.png"
	var a = ResourceLoader.load(d)
	print(a)
	print(a is Image)
	var papertexture = ImageTexture.new()
	papertexture.create_from_image(a)
	print(papertexture.get_width())
