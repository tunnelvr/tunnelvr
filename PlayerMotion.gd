extends Spatial

#var Ddebugvisualoffset = Vector3(-2, 0, 0)
var Ddebugvisualoffset = Vector3(0, 0, 0)

onready var playerMe = get_node("/root/Spatial/Players/PlayerMe")
onready var HeadCam = playerMe.get_node("HeadCam")
onready var HeadCentre = HeadCam.get_node("HeadCentre")
onready var HeadCollisionWarning = HeadCam.get_node("HeadCollisionWarning")
onready var playerheadbodyradius = $PlayerKinematicBody/PlayerBodyCapsule.shape.radius
onready var HandLeft = playerMe.get_node("HandLeft")
onready var PlayerDirections = get_node("../PlayerDirections")

var floor_max_angle = deg2rad(45)
var floor_max_angle_gradient = sin(floor_max_angle)
var floor_max_angle_wallgradient = cos(floor_max_angle)
var gravityacceleration = 13.0
var playerbodyabsoluteheight = 2.2  # tall person (no jumping for now)
var playermaxstepupheight = 0.3
var playerstepdownbump = 0.05
var freefallsurfaceslidedragfactor = 1.1
var freefallairdragfactor = 0.8
var flyingkinematicenlargement = 0.03
var clawengagementmaxpulldistance = 0.18

onready var psqparams = PhysicsShapeQueryParameters.new()
onready var psqparamshead = PhysicsShapeQueryParameters.new()
var headcentrefromvroriginvector = Vector3(0,1.6,0)
var headcentreabovephysicalfloorheight = 1.7
var playerbodyverticalheight = 1.1
var playerheadcentreabovebodycentreheight = 0.4
var playerbodycentre = Vector3(0,0,0)

var playerinfreefall = false
var playerfreefallbodyvelocity = null
var playerdirectedflight_prev = false
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

func resetplayervelocitystack(n):
	playercentrevelocitystack_index = n


func _ready():
	var visualpreview = (Ddebugvisualoffset != Vector3(0,0,0))
	$PlayerKinematicBody/PlayerBodyCapsule/CapsuleShapePreview.visible = visualpreview
	$MotionVectorPreview.visible = visualpreview
	$PlayerKinematicBody/PlayerBodyCapsule/CapsuleShapePreview.visible = false
	
	psqparams.set_shape($PlayerKinematicBody/PlayerBodyCapsule.shape)
	psqparams.collision_mask = $PlayerKinematicBody.collision_mask

	psqparamshead.set_shape($PlayerHeadKinematicBody/PlayerHeadCapsule.shape)
	psqparamshead.collision_mask = $PlayerKinematicBody.collision_mask

	$PlayerEnlargedKinematicBody/PlayerBodyCapsule.shape.radius = playerheadbodyradius + flyingkinematicenlargement

var physicsprocessTimeStamp = 0
func _physics_process(delta):
	physicsprocessTimeStamp += delta

	# The Quest reliably spits out a run of bad camera orientation (translated into nans in the HeadCentre) between time stamp 0.15 and 0.26667
	if is_nan(HeadCentre.global_transform.origin.x):
		print(" skipping bad headcam position:", physicsprocessTimeStamp, " orientation ", HeadCam.global_transform.basis.x)
		return

	if PlayerDirections.nextphysicsrotatestep != 0.0:
		var t1 = Transform(Basis(), -HeadCam.transform.origin)
		var t2 = Transform(Basis(), HeadCam.transform.origin)
		var rot = Transform().rotated(Vector3(0.0, -1, 0.0), deg2rad(PlayerDirections.nextphysicsrotatestep))
		playerMe.transform *= t2*rot*t1
		PlayerDirections.nextphysicsrotatestep = 0.0
		
	if PlayerDirections.newgreenblobposition != null:
		#get_node("/root/Spatial/GuiSystem/GreenBlob").global_transform.origin = PlayerDirections.newgreenblobposition
		var greenblob = get_node("/root/Spatial/GuiSystem/GreenBlob")
		var tween = greenblob.get_node("Tween")
		var endtrans = PlayerDirections.newgreenblobposition - playerMe.global_transform.origin
		var dist = greenblob.translation.distance_to(endtrans)
		var dt = min(0.8, 1.1*dist)
		tween.interpolate_property(greenblob, "translation", greenblob.translation, endtrans, dt, Tween.TRANS_QUART, Tween.EASE_OUT)
		#tween.interpolate_property(greenblob, "translation", greenblob.translation, PlayerDirections.newgreenblobposition, 1, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
		PlayerDirections.newgreenblobposition = null
		tween.start()
		
	headcentrefromvroriginvector = HeadCentre.global_transform.origin - playerMe.global_transform.origin
	headcentreabovephysicalfloorheight = max(headcentrefromvroriginvector.y, playerheadbodyradius)
	playerbodyverticalheight = min(playerbodyabsoluteheight, playerheadbodyradius + headcentreabovephysicalfloorheight)
	playerheadcentreabovebodycentreheight = playerbodyverticalheight/2 - playerheadbodyradius

	var capsuleshaftheight = playerbodyverticalheight - 2*playerheadbodyradius
	$PlayerKinematicBody/PlayerBodyCapsule.shape.height = capsuleshaftheight
	$PlayerKinematicBody/PlayerBodyCapsule/CapsuleShapePreview.mesh.mid_height = capsuleshaftheight
	
	if PlayerDirections.clawengageposition != null:
		var clawengagementrelativedisplacement = PlayerDirections.clawengageposition - PlayerDirections.GroundSpikePoint.global_transform.origin
		if playerinfreefall:
			endfreefallmode()
		process_clawengagement(delta, clawengagementrelativedisplacement)
	elif PlayerDirections.playerdirectedflight:
		process_directedflight(delta, PlayerDirections.playerdirectedflightvelocity)
	elif playerinfreefall:
		process_freefall(delta)
	else:
		var playerdirectedwalkmovement = process_directedwalkmovement(delta, PlayerDirections.playerdirectedwalkingvelocity) if PlayerDirections.playerdirectedwalkingvelocity != Vector3(0,0,0) else Vector3(0,0,0)
		process_feet_on_floor(delta, playerdirectedwalkmovement)
	process_shareplayerposition()
	playerdirectedflight_prev = PlayerDirections.playerdirectedflightvelocity

	$FloorOriginMarker.global_transform = playerMe.global_transform
	if $MotionVectorPreview.visible:
		var playercentrevelocity = playerfreefallbodyvelocity if playerinfreefall and not PlayerDirections.playerdirectedflight else getplayerrecentvelocity()
		var playercentrevelocitylength = playercentrevelocity.length()
		$MotionVectorPreview/Scale.scale.z = playercentrevelocitylength
		if playercentrevelocitylength > 0.01:
			$MotionVectorPreview.global_transform = Transform(Basis(), playerbodycentre).looking_at(playerbodycentre - playercentrevelocity, Vector3(0,1,0) if abs(playercentrevelocity.y) < 0.8*playercentrevelocitylength else Vector3(1,0,0))

func process_clawengagement(delta, clawengagementrelativedisplacement):
	playerbodycentre = HeadCentre.global_transform.origin - Vector3(0, playerheadcentreabovebodycentreheight, 0) + Ddebugvisualoffset
	var playerbodycapsulebasis = $PlayerKinematicBody/PlayerBodyCapsule.global_transform.basis
	var playerbodycentrewithdirectedmotion = playerbodycentre + clawengagementrelativedisplacement
	psqparams.transform = Transform(playerbodycapsulebasis, playerbodycentrewithdirectedmotion + Vector3(0,0.05,0))
	if len(get_world().direct_space_state.intersect_shape(psqparams, 1)) == 0:
		playerMe.global_transform.origin += clawengagementrelativedisplacement
		playerbodycentre = playerbodycentrewithdirectedmotion
	else:
		PlayerDirections.endclawengagement()
	addplayervelocitystack((playerbodycentre - playerbodycentre_prev)/delta)
	playerbodycentre_prev = playerbodycentre
	$PlayerKinematicBody.global_transform.origin = playerbodycentre
		

func process_feet_on_floor(delta, playerdirectedwalkmovement):
	playerbodycentre = HeadCentre.global_transform.origin - Vector3(0, playerheadcentreabovebodycentreheight, 0) + Ddebugvisualoffset
	
	var playeriscolliding = false
	var playerheadcolliding = false	
	var playerstartsfreefall = false

	var stepupdistanceclear = playermaxstepupheight
	var playerbodycapsulebasis = $PlayerKinematicBody/PlayerBodyCapsule.global_transform.basis
	var playerbodycentrewithdirectedmotion = playerbodycentre + playerdirectedwalkmovement
	psqparams.transform = Transform(playerbodycapsulebasis, playerbodycentrewithdirectedmotion + Vector3(0, stepupdistanceclear, 0))
	if len(get_world().direct_space_state.intersect_shape(psqparams, 1)) != 0:
		stepupdistanceclear = playermaxstepupheight/2
		psqparams.transform = Transform(playerbodycapsulebasis, playerbodycentrewithdirectedmotion + Vector3(0, stepupdistanceclear, 0))
		if len(get_world().direct_space_state.intersect_shape(psqparams, 1)) != 0:
			stepupdistanceclear = -playerstepdownbump
			psqparams.transform = Transform(playerbodycapsulebasis, playerbodycentrewithdirectedmotion + Vector3(0, stepupdistanceclear, 0))
			if len(get_world().direct_space_state.intersect_shape(psqparams, 1)) != 0:
				playeriscolliding = true
	
	if not playeriscolliding and playerdirectedwalkmovement != Vector3(0,0,0):
		playerMe.global_transform.origin += playerdirectedwalkmovement
		playerbodycentre = playerbodycentrewithdirectedmotion
		assert (playerbodycentre.is_equal_approx(HeadCentre.global_transform.origin - Vector3(0, playerheadcentreabovebodycentreheight, 0) + Ddebugvisualoffset))
	
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
#		print("HHH  ", playerMe.global_transform.origin.y, "  ", playerbodycentre.y, "  ", playerheadcentreabovebodycentreheight, "  ", headcentreabovephysicalfloorheight)
		playerMe.global_transform.origin.y = playerbodycentre.y + playerheadcentreabovebodycentreheight - headcentreabovephysicalfloorheight
		$PlayerKinematicBody.global_transform.origin = playerbodycentre
		addplayervelocitystack((playerbodycentre - playerbodycentre_prev)/delta)
		playerbodycentre_prev = playerbodycentre
		if playerstartsfreefall:
			$PlayerKinematicBody/PlayerBodyCapsule/CapsuleShapePreview/FreefallWarning.visible = true
			playerfreefallbodyvelocity = getplayerrecentvelocity()
			playerinfreefall = true
	else:
		resetplayervelocitystack(-2)
		var playerheadcentreforcollision = playerbodycentre + Vector3(0, playerheadcentreabovebodycentreheight, 0)
		psqparamshead.transform = Transform(playerbodycapsulebasis, playerheadcentreforcollision)
		playerheadcolliding = len(get_world().direct_space_state.intersect_shape(psqparamshead, 1)) != 0
		$PlayerHeadKinematicBody/PlayerHeadCapsule.global_transform.origin = playerheadcentreforcollision

	$PlayerKinematicBody.global_transform.origin = playerbodycentre
	$PlayerKinematicBody/PlayerBodyCapsule/CapsuleShapePreview/CollisionWarning.visible = playeriscolliding
	$PlayerKinematicBody/PlayerBodyCapsule/CapsuleShapePreview/HeadCollisionWarning.visible = playerheadcolliding
	HeadCollisionWarning.visible = playerheadcolliding
	
func endfreefallmode():
	resetplayervelocitystack(-1)
	playerinfreefall = false
	$PlayerKinematicBody/PlayerBodyCapsule/CapsuleShapePreview/FreefallWarning.visible = false
	
func process_freefall(delta):
	$PlayerKinematicBody.global_transform.origin = playerbodycentre
	playerfreefallbodyvelocity.y -= gravityacceleration*delta
	playerfreefallbodyvelocity *= 1.0 - freefallairdragfactor*delta
	playerfreefallbodyvelocity = $PlayerKinematicBody.move_and_slide(playerfreefallbodyvelocity, Vector3(0, 1, 0))
	playerbodycentre = $PlayerKinematicBody.global_transform.origin
	playerMe.global_transform.origin = -Ddebugvisualoffset + playerbodycentre + Vector3(0, playerheadcentreabovebodycentreheight, 0) - headcentrefromvroriginvector
	var slidecount = $PlayerKinematicBody.get_slide_count()
	if slidecount > 0:
		var slidecollision = $PlayerKinematicBody.get_slide_collision(slidecount - 1)
		var slideincidence = -slidecollision.normal.dot(playerfreefallbodyvelocity)
		print(playerbodycentre, slideincidence, playerfreefallbodyvelocity, freefallsurfaceslidedragfactor, " delta ", delta)
		playerfreefallbodyvelocity *= 1 - max(0, slideincidence)*freefallsurfaceslidedragfactor*delta
		if slidecollision.normal.y > floor_max_angle_wallgradient:
			endfreefallmode()
	playerbodycentre_prev = playerbodycentre

func process_directedwalkmovement(delta, playerdirectedwalkingvelocity):
	var directedcollisionstepup = playermaxstepupheight/2
	var capsuleshaftheight = playerbodyverticalheight - 2*playerheadbodyradius - directedcollisionstepup*2
	$PlayerEnlargedKinematicBody/PlayerBodyCapsule.shape.height = capsuleshaftheight
	$PlayerEnlargedKinematicBody.global_transform.origin = playerbodycentre + Vector3(0, directedcollisionstepup, 0)
	$PlayerEnlargedKinematicBody.move_and_slide(playerdirectedwalkingvelocity, Vector3(0, 1, 0))
	var playerdirectedwalkmovement = $PlayerEnlargedKinematicBody.global_transform.origin - playerbodycentre
	playerdirectedwalkmovement.y = 0
	if playerdirectedwalkingvelocity.dot(playerdirectedwalkmovement) > 0:
		return playerdirectedwalkmovement
	return Vector3(0,0,0)

func process_directedflight(delta, playerdirectedflightvelocity):
	if not playerdirectedflight_prev:
		playerbodycentre = HeadCentre.global_transform.origin - Vector3(0, playerheadcentreabovebodycentreheight, 0) + Ddebugvisualoffset
		playerbodycentre_prev = playerbodycentre
	var capsuleshaftheight = playerbodyverticalheight - 2*playerheadbodyradius
	$PlayerEnlargedKinematicBody/PlayerBodyCapsule.shape.height = capsuleshaftheight
	$PlayerEnlargedKinematicBody.global_transform.origin = playerbodycentre
	if playerdirectedflightvelocity != Vector3(0,0,0):
		playerfreefallbodyvelocity = $PlayerEnlargedKinematicBody.move_and_slide(playerdirectedflightvelocity, Vector3(0, 1, 0))
		playerbodycentre = $PlayerEnlargedKinematicBody.global_transform.origin
	playerMe.global_transform.origin = -Ddebugvisualoffset + playerbodycentre + Vector3(0, playerheadcentreabovebodycentreheight, 0) - headcentrefromvroriginvector
	addplayervelocitystack((playerbodycentre - playerbodycentre_prev)/delta)
	playerbodycentre_prev = playerbodycentre
	$PlayerKinematicBody.global_transform.origin = playerbodycentre

func process_shareplayerposition():
	var doppelganger = playerMe.doppelganger
	if is_inside_tree() and is_instance_valid(doppelganger):
		var positiondict = playerMe.playerpositiondict()
		positiondict["playertransform"] = Transform(Basis(-positiondict["playertransform"].basis.x, positiondict["playertransform"].basis.y, -positiondict["playertransform"].basis.z), 
													Vector3(doppelganger.global_transform.origin.x, positiondict["playertransform"].origin.y, doppelganger.global_transform.origin.z))
		if playerMe.bouncetestnetworkID != 0:
			playerMe.rpc_unreliable_id(playerMe.bouncetestnetworkID, "bouncedoppelgangerposition", playerMe.networkID, positiondict)
		else:
			doppelganger.setavatarposition(positiondict)
	if Tglobal.connectiontoserveractive:
		playerMe.rpc_unreliable("setavatarposition", playerMe.playerpositiondict())
