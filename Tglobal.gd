extends Node

var tubedxcsvisible = false
var tubeshellsvisible = true
var centrelinevisible = false
var centrelineonly = false
var connectiontoserveractive = false

# could store for arvrinterface.get_tracking_status() == ARVRInterface.ARVR_NOT_TRACKING
var VRoperating = false
var arvrinterface = null
var VRstatus = "unknown"   # should be a flag
var questhandtracking = false

var soundsystem = null
