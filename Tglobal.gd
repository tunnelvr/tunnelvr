extends Node

var connectiontoserveractive = false
var morethanoneplayer = false
var printxcdrawingfromdatamessages = true

var arvrinterfacename = "none"  # OVRMobile, Oculus, OpenVR
var arvrinterface = null
var VRoperating = false

var controlslocked = false
var questhandtracking = false
var questhandtrackingactive = false

var handflickmotiongestureposition = 0
var soundsystem = null
const version = "v0.5.3"

var hidecavewallstoseefloors = false
