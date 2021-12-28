extends StaticBody

onready var _virtual_keyboard = $Viewport/VirtualKeyboard;
onready var _refrence_button = $Viewport/VirtualKeyboard/ReferenceButton;
onready var _container_letters = $Viewport/VirtualKeyboard/Container_Letters
onready var _container_symbols = $Viewport/VirtualKeyboard/Container_Symbols

export var allow_newline = true;
const B_SIZE = 48;

const NUMBER_LAYOUT = ["1","2","3","4","5","6","7","8","9","0"];

const BUTTON_LAYOUT_ENGLISH = [
["q","w","e","r","t","y","u","i","o","p"],
["a","s","d","f","g","h","j","k","l",":"],
["@","z","x","c","v","b","n","m","!","."],
["/"],
];

const BUTTON_LAYOUT_SYMBOLS = [
["!","@","#","$","%","^","&","*","(",")"],
[".",'"',"'",",","-","?",":",";","{","}"],
["+","_","=","|","/","\\","<",">","[","]"],
];

var current_viewport_mousedown = false
var collision_point = Vector3(0, 0, 0)
var viewport_point = Vector2(0, 0)

onready var viewportforvirtualkeyboard = get_node("/root/Spatial/GuiSystem/GUIPanel3D/Viewport")


signal enter_pressed;
#signal cancel_pressed;

var _all_letter_buttons = [];

func _toggle_case(upper):
	if (upper):
		for b in _all_letter_buttons:
			b.text = b.text.to_upper();
	else:
		for b in _all_letter_buttons:
			b.text = b.text.to_lower();
			
func _toggle_symbols(show_symbols):
	if (show_symbols):
		_container_letters.visible = false;
		_container_symbols.visible = true;
	else:
		_container_letters.visible = true;
		_container_symbols.visible = false;


func _create_input_event(b, pressed):
	var scancode = 0;
	var key = b.text;
	var unicode = 0;

	if (b == _toggle_symbols_button):
		_toggle_symbols(b.pressed);
		return;
	elif (b == _cancel_button):
		scancode = KEY_TAB  # doesn't seem to get decoded to right place
		var textedit = viewportforvirtualkeyboard.get_node("GUI").get_focus_owner()
		if textedit != null:
			textedit.release_focus()
		return
	elif b == _shift_button:
		if (pressed): 
			_toggle_case(!b.pressed); # button event is created before it is actually toggled
		scancode = KEY_SHIFT;
	elif b == _delete_button:
		scancode = KEY_BACKSPACE;
	elif b == _clear_button:
		scancode = KEY_CLEAR;
		var textedit = viewportforvirtualkeyboard.get_node("GUI").get_focus_owner()
		if textedit != null and textedit.get_class() == "TextEdit":
			textedit.text = ""
	elif b == _left_button:
		scancode = KEY_LEFT
	elif b == _right_button:
		scancode = KEY_RIGHT
	elif b == _up_button:
		scancode = KEY_UP
	elif b == _down_button:
		scancode = KEY_DOWN

	elif (b == _enter_button):
		scancode = KEY_ENTER;
		if (!pressed): emit_signal("enter_pressed");
		if (!allow_newline): return; # no key event for enter in this case
	elif (b == _space_button):
		scancode = KEY_SPACE;
		key = " ";
		unicode = " ".ord_at(0);
	else:
		scancode = OS.find_scancode_from_string(b.text);
		unicode = key.ord_at(0);
	

	#print("  Event for " + key + ": scancode = " + str(scancode));
	
	var ev = InputEventKey.new();
	ev.scancode = scancode;
	ev.unicode = unicode;
	ev.pressed = pressed;

	return ev;


# not sure what causes this yet but it happens that a button press
# triggers twice the down without up
var _last_button_down_hack = null;

func _on_button_down(b):
	if (b == _last_button_down_hack): return;
	_last_button_down_hack = b;
	
	var ev = _create_input_event(b, true);
	if (!ev): return;
	viewportforvirtualkeyboard.input(ev)

	var viewport_point = b.rect_position + b.rect_size*0.5
	var local_point2 = viewport_point/($Viewport.size)
	var local_point = Vector3(local_point2.x, -local_point2.y, 0)
	local_point -= Vector3(0.5, -0.5, 0) # X is about 0 to 1, Y is about 0 to -1.
	local_point *= get_node("CollisionShape").shape.extents * 2
	var raycastcollisionpoint = global_transform.xform(local_point)
	var sketchsystem = get_node("/root/Spatial/SketchSystem")
	Tglobal.soundsystem.quicksound("ClickSound", raycastcollisionpoint)
	Tglobal.soundsystem.shortvibrate(false, 0.03, 1.0)
			
func _on_button_up(b):
	_last_button_down_hack = null;
	var ev = _create_input_event(b, false);
	if ev:
		viewportforvirtualkeyboard.input(ev)

func _on_mouse_entered():
	Tglobal.soundsystem.shortvibrate(false, 0.025, 1.0)

func _create_button(_parent, text, x, y, w = 1, h = 1):
	var b = _refrence_button.duplicate()
	if text[0] == "&" and text[-1] == ";":
		assert ("&#0041;".xml_unescape() == ")")  # https://github.com/godotengine/godot/issues/56298
		text = ("&#%d;" % ("0x"+text.substr(2, 4)).hex_to_int())
		text = text.xml_unescape()	
	b.text = text;
	
	if (b.text.length() == 1):
		var c = b.text.ord_at(0);
		if (c >= 97 && c <= 122):
			_all_letter_buttons.append(b);
	
	b.rect_position = Vector2(x, y) * B_SIZE;
	b.rect_min_size = Vector2(w, h) * B_SIZE;
	
	b.name = "button_"+text;
	
	b.connect("button_down", self, "_on_button_down", [b]);
	b.connect("button_up", self, "_on_button_up", [b]);
	b.connect("mouse_entered", self, "_on_mouse_entered");
		
	_parent.add_child(b);
	return b;

var _toggle_symbols_button : Button = null;
var _shift_button : Button = null;
var _delete_button : Button = null;
var _clear_button : Button = null;
var _enter_button : Button = null;
var _space_button : Button = null;
var _cancel_button : Button = null;
var _left_button : Button = null
var _right_button : Button = null
var _up_button : Button = null
var _down_button : Button = null

func _create_keyboard_buttons():
	_toggle_symbols_button = _create_button(_virtual_keyboard, "#$%", 0+1, 1, 2, 1);
	_toggle_symbols_button.set_rotation(deg2rad(90.0));
	_toggle_symbols_button.toggle_mode = true;
	
	_shift_button = _create_button(_virtual_keyboard, "&#21E7;", 0, 3, 1, 2);
	_shift_button.toggle_mode = true;
	
	_delete_button = _create_button(_virtual_keyboard, "&#232B;", 11, 1, 1, 1); # "&#232B;".xml_unescape()
	_clear_button = _create_button(_virtual_keyboard, "&#25A1;", 11, 2, 1, 1);
	_enter_button = _create_button(_virtual_keyboard, "&#23CE;", 11, 3, 1, 2);
	
	_space_button = _create_button(_virtual_keyboard, "Space", 2, 4, 6, 1);

	_left_button = _create_button(_virtual_keyboard, "&#2B05;", 8, 4, 1, 1);
	_up_button = _create_button(_virtual_keyboard, "&#2B06;", 9, 4, 1, 1);
	_down_button = _create_button(_virtual_keyboard, "&#2B07;", 9, 4, 1, 1);
	_right_button = _create_button(_virtual_keyboard, "&#27A1;", 10, 4, 1, 1);
	
	_cancel_button = _create_button(_virtual_keyboard, "&#2327;".xml_unescape(), 11, 0, 1, 1);
	_up_button.rect_scale = Vector2(1, 0.5)
	_down_button.rect_scale = Vector2(1, 0.5)
	_down_button.rect_position.y += B_SIZE/2
	var x = 1;
	var y = 0;
	
	for k in NUMBER_LAYOUT:
		_create_button(_virtual_keyboard, k, x, y);
		x += 1;
		
	x = 1;
	y = 1;
	# standard buttons
	for line in BUTTON_LAYOUT_ENGLISH:
		for k in line:
			_create_button(_container_letters, k, x, y);
			x += 1;
		y += 1;
		x = 1;
		
	x = 1;
	y = 1;
	# standard buttons
	for line in BUTTON_LAYOUT_SYMBOLS:
		for k in line:
			_create_button(_container_symbols, k, x, y);
			x += 1;
		y += 1;
		x = 1;

		
	_refrence_button.visible = false;
	_toggle_symbols(_toggle_symbols_button.pressed);



func _ready():
	if has_node("ViewportReal"):
		var fgui = $Viewport/VirtualKeyboard
		$Viewport.remove_child(fgui)
		$ViewportReal.add_child(fgui)
		$Viewport.set_name("ViewportFake")
		$ViewportReal.set_name("Viewport")
		$Quad.get_surface_material(0).albedo_texture = $Viewport.get_texture()
		
	#$Viewport.render_target_update_mode = Viewport.UPDATE_DISABLED
	_create_keyboard_buttons();


