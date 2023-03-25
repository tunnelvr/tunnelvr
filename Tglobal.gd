extends Node

const tunnelvrversion = "v0.8.0"

var connectiontoserveractive = false
var morethanoneplayer = false
var notisloadingcavechunks = true

var arvrinterfacename = "none"  # OpenXR, Oculus, OpenVR
var arvrinterface = null
var VRoperating = false

var controlslocked = false
var virtualkeyboardactive = false
var questhandtracking = false
var questhandtrackingactive = false

var handflickmotiongestureposition = 0
var soundsystem = null

var hidecavewallstoseefloors = false

var primarycamera_instanceid = 0

var phoneoverlay = null
var phonethumbmotionposition = null
var phonethumbviewposition = null

# facts lifted from the attributes of the centreline
var housahedronmode = false
var splaystationnoderegex = null
func _ready():
	splaystationnoderegex = RegEx.new()
	splaystationnoderegex.compile("_\\d+$|.*[^\\d]$")

	
