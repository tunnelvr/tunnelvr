extends Spatial

onready var playerMe = get_node("/root/Spatial/Players/PlayerMe")
onready var HeadCam = playerMe.get_node("HeadCam")
onready var HeadCentre = HeadCam.get_node("HeadCentre")
onready var playerheadbodyradius = $PlayerKinematicBody/PlayerBodyCapsule.shape.radius
onready var psqparams = PhysicsShapeQueryParameters.new()
onready var HandLeft = playerMe.get_node("HandLeft")

var floor_max_angle = deg2rad(45)
var floor_max_angle_gradient = sin(floor_max_angle)
var floor_max_angle_wallgradient = cos(floor_max_angle)
var gravityacceleration = 13.0
var playerbodyabsoluteheight = 2.2  # tall person (no jumping for now)
var playermaxstepupheight = 0.3
var playerstepdownbump = 0.05
var freefallsurfaceslidedragfactor = 1.1
var freefallairdragfactor = 0.8
var flyspeed = 5.0

var Ddebugvisualoffset = Vector3(-2, 0, 0)

var headcentrefromvroriginvector = Vector3(0,1.6,0)
var headcentreabovephysicalfloorheight = 1.7
var playerbodyverticalheight = 1.1
var playerheadcentreabovebodycentreheight = 0.4
var playerbodycentre = Vector3(0,0,0)

var playerinfreefall = false
var playerfreefallbodyvelocity = null
var playerdirectedflight = false
var playerdirectedflightvelocity = Vector3(0,0,0)
var playerbodycentre_prev = Vector3(0,0,0)
var playercentrevelocitystack = [ Vector3(0,0,0), Vector3(0,0,0), Vector3(0,0,0), Vector3(0,0,0) ]
var playercentrevelocitystack_index = -2

func getplayerrecentvelocity():
	if playercentrevelocitystack_index >= 0:
		var velsum = playercentrevelocitystack[0]
		for i in range(1, len(playercentrevelocitystack)):
			velsum += playercentrevelocitystack[i]
		return velsum/len(playercentrevelocitystack)
	return Vector3(0,0,0)


func addplayervelocitystack(vel):
	if playercentrevelocitystack_index >= -1:
		if playercentrevelocitystack_index >= 0:
			playercentrevelocitystack[playercentrevelocitystack_index] = vel
		else:
			for i in range(len(playercentrevelocitystack)):
				playercentrevelocitystack[i] = vel
		playercentrevelocitystack_index = (playercentrevelocitystack_index + 1)%len(playercentrevelocitystack)
	else:
		playercentrevelocitystack_index += 1

func determdirectedflight():
	playerdirectedflight = HandLeft.is_button_pressed(BUTTONS.VR_GRIP) or Input.is_action_pressed("lh_fly")
	if playerdirectedflight:
		var joypos = Vector2(HandLeft.get_joystick_axis(0), HandLeft.get_joystick_axis(1)) if (HandLeft.get_is_active() and not Tglobal.questhandtracking) else Vector2(0.0, 0.0)
		if HandLeft.is_button_pressed(BUTTONS.VR_TRIGGER) or Input.is_action_pressed("lh_forward") or Input.is_action_pressed("lh_backward"):
			var flydir = HandLeft.global_transform.basis.z if HandLeft.get_is_active() else HeadCam.global_transform.basis.z
			if joypos.y < -0.5:
				flydir = -flydir
			playerdirectedflightvelocity = -flydir.normalized()*flyspeed
			if HandLeft.is_button_pressed(BUTTONS.VR_PAD):
				playerdirectedflightvelocity *= 3.0
		else:
			playerdirectedflightvelocity = Vector3(0,0,0)
	else:
		pass

func _ready():
	var visualpreview = (Ddebugvisualoffset != Vector3(0,0,0))
	$PlayerKinematicBody/PlayerBodyCapsule/CapsuleShapePreview.visible = visualpreview
	$FloorOriginMarker.visible = visualpreview
	$MotionVectorPreview.visible = visualpreview

	psqparams.set_shape($PlayerKinematicBody/PlayerBodyCapsule.shape)
	psqparams.collision_mask = $PlayerKinematicBody.collision_mask

func _physics_process(delta):
	headcentrefromvroriginvector = HeadCentre.global_transform.origin - playerMe.global_transform.origin
	headcentreabovephysicalfloorheight = max(headcentrefromvroriginvector.y, playerheadbodyradius)
	playerbodyverticalheight = min(playerbodyabsoluteheight, playerheadbodyradius + headcentreabovephysicalfloorheight)
	playerheadcentreabovebodycentreheight = playerbodyverticalheight/2 - playerheadbodyradius

	var capsuleshaftheight = playerbodyverticalheight - 2*playerheadbodyradius
	$PlayerKinematicBody/PlayerBodyCapsule.shape.height = capsuleshaftheight
	$PlayerKinematicBody/PlayerBodyCapsule/CapsuleShapePreview.mesh.mid_height = capsuleshaftheight
	
	determdirectedflight()
	if playerdirectedflight:
		process_directedflight(delta)
	elif playerinfreefall:
		process_freefall(delta)
	else:
		process_feet_on_floor(delta)

	var playerfootheight = playerbodycentre.y - playerbodyverticalheight/2
	playerfootheight = playerMe.global_transform.origin.y
	$FloorOriginMarker.global_transform = playerMe.global_transform
	if $MotionVectorPreview.visible:
		var playercentrevelocity = playerfreefallbodyvelocity if playerinfreefall and not playerdirectedflight else getplayerrecentvelocity()
		var playercentrevelocitylength = playercentrevelocity.length()
		$MotionVectorPreview/Scale.scale.z = playercentrevelocitylength
		if playercentrevelocitylength > 0.01:
			$MotionVectorPreview.global_transform = Transform(Basis(), playerbodycentre).looking_at(playerbodycentre - playercentrevelocity, Vector3(0,1,0) if abs(playercentrevelocity.y) < 0.8*playercentrevelocitylength else Vector3(1,0,0))
	else:
		print(playerfootheight)
		
func process_feet_on_floor(delta):
	playerbodycentre = HeadCentre.global_transform.origin - Vector3(0, playerheadcentreabovebodycentreheight, 0) + Ddebugvisualoffset
	
	var playeriscolliding = false
	var playerstartsfreefall = false

	var stepupdistanceclear = playermaxstepupheight
	var playerbodycapsulebasis = $PlayerKinematicBody/PlayerBodyCapsule.global_transform.basis
	psqparams.transform = Transform(playerbodycapsulebasis, playerbodycentre + Vector3(0, stepupdistanceclear, 0))
	if len(get_world().direct_space_state.intersect_shape(psqparams, 1)) != 0:
		stepupdistanceclear = playermaxstepupheight/2
		psqparams.transform = Transform(playerbodycapsulebasis, playerbodycentre + Vector3(0, stepupdistanceclear, 0))
		if len(get_world().direct_space_state.intersect_shape(psqparams, 1)) != 0:
			stepupdistanceclear = -playerstepdownbump
			psqparams.transform = Transform(playerbodycapsulebasis, playerbodycentre + Vector3(0, stepupdistanceclear, 0))
			if len(get_world().direct_space_state.intersect_shape(psqparams, 1)) != 0:
				playeriscolliding = true
	
	var stepupdistance = 0.0
	if not playeriscolliding:
		if stepupdistanceclear > 0:
			var downcastdistance = stepupdistanceclear + playerstepdownbump
			var dropcollision = get_world().direct_space_state.cast_motion(psqparams, Vector3(0, -downcastdistance, 0))
			if len(dropcollision) != 0 and dropcollision[0] != 0.0:
				if dropcollision[0] == 1.0:
					playerstartsfreefall = true
					stepupdistance = 0.0
				else:
					var downcastlam = dropcollision[0] # (dropcollision[0]+dropcollision[1])/2
					stepupdistance = stepupdistanceclear - downcastlam*downcastdistance
			else:
				print(" error, cast_motion staring point not clear of collisions")
				playeriscolliding = true
		else:
			stepupdistance = stepupdistanceclear

	if not playeriscolliding:
		playerbodycentre.y += stepupdistance
		playerMe.global_transform.origin.y = playerbodycentre.y + playerheadcentreabovebodycentreheight - headcentreabovephysicalfloorheight
		$PlayerKinematicBody.global_transform.origin = playerbodycentre
		addplayervelocitystack((playerbodycentre - playerbodycentre_prev)/delta)
		playerbodycentre_prev = playerbodycentre
		if playerstartsfreefall:
			$PlayerKinematicBody/PlayerBodyCapsule/CapsuleShapePreview/FreefallWarning.visible = true
			playerfreefallbodyvelocity = getplayerrecentvelocity()
			playerinfreefall = true
	else:
		playercentrevelocitystack_index = -2
	$PlayerKinematicBody.global_transform.origin = playerbodycentre
	$PlayerKinematicBody/PlayerBodyCapsule/CapsuleShapePreview/CollisionWarning.visible = playeriscolliding


func process_freefall(delta):
	$PlayerKinematicBody.global_transform.origin = playerbodycentre
	playerfreefallbodyvelocity.y -= gravityacceleration*delta
	playerfreefallbodyvelocity *= 1.0 - freefallairdragfactor*delta
	playerfreefallbodyvelocity = $PlayerKinematicBody.move_and_slide(playerfreefallbodyvelocity, Vector3(0, 1, 0))
	playerbodycentre = $PlayerKinematicBody.global_transform.origin
	#print("playerbodycentre ", playerbodycentre, playerfreefallbodyvelocity)
	playerMe.global_transform.origin = -Ddebugvisualoffset + playerbodycentre + Vector3(0, playerheadcentreabovebodycentreheight, 0) - headcentrefromvroriginvector
	var slidecount = $PlayerKinematicBody.get_slide_count()
	if slidecount > 0:
		var slidecollision = $PlayerKinematicBody.get_slide_collision(slidecount - 1)
		var slideincidence = -slidecollision.normal.dot(playerfreefallbodyvelocity)
		playerfreefallbodyvelocity *= 1 - max(0, slideincidence)*freefallsurfaceslidedragfactor*delta
		if slidecollision.normal.y > floor_max_angle_wallgradient:
			playercentrevelocitystack_index = -1
			playerinfreefall = false
			$PlayerKinematicBody/PlayerBodyCapsule/CapsuleShapePreview/FreefallWarning.visible = false		
	playerbodycentre_prev = playerbodycentre

func process_directedflight(delta):
	$PlayerKinematicBody.global_transform.origin = playerbodycentre
	if playerdirectedflightvelocity != Vector3(0,0,0):
		playerfreefallbodyvelocity = $PlayerKinematicBody.move_and_slide(playerdirectedflightvelocity, Vector3(0, 1, 0))
		playerbodycentre = $PlayerKinematicBody.global_transform.origin
	playerMe.global_transform.origin = -Ddebugvisualoffset + playerbodycentre + Vector3(0, playerheadcentreabovebodycentreheight, 0) - headcentrefromvroriginvector
	playerbodycentre_prev = playerbodycentre
	addplayervelocitystack((playerbodycentre - playerbodycentre_prev)/delta)
