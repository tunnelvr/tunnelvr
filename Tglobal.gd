extends Node

const tunnelvrversion = "v0.7.5"

var connectiontoserveractive = false
var morethanoneplayer = false
var printxcdrawingfromdatamessages = true

var arvrinterfacename = "none"  # OVRMobile, Oculus, OpenVR
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

var splaystationnoderegex = null
func _ready():
	splaystationnoderegex = RegEx.new()
	splaystationnoderegex.compile(".*[^\\d]$")
	
