extends Spatial

#var Ddebugvisualoffset = Vector3(-2, 0, 0)   # put Visible Collision Shapes on when you do this
var Ddebugvisualoffset = Vector3(0, 0, 0)

onready var playerMe = get_node("/root/Spatial/Players/PlayerMe")
onready var HeadCam = playerMe.get_node("HeadCam")
onready var HeadCentre = HeadCam.get_node("HeadCentre")
onready var HeadCollisionWarning = HeadCam.get_node("HeadCollisionWarning")
onready var playerheadbodyradius = $PlayerKinematicBody/PlayerBodyCapsule.shape.radius
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
var gravityenabled = true

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

var footstepcount = 0
const footsteplength = 0.4
const footstepduration = 0.5
var prevfootsteptimestamp = 0
var prevfootstepposition = Vector3(0, 0, 0)
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
		# could add footstep count here
		
	headcentrefromvroriginvector = HeadCentre.global_transform.origin - playerMe.global_transform.origin
	headcentreabovephysicalfloorheight = max(headcentrefromvroriginvector.y, playerheadbodyradius)
	playerbodyverticalheight = min(playerbodyabsoluteheight, playerheadbodyradius + headcentreabovephysicalfloorheight)
	playerheadcentreabovebodycentreheight = playerbodyverticalheight/2 - playerheadbodyradius

	if physicsprocessTimeStamp - prevfootsteptimestamp > footstepduration:
		var footstepposition = HeadCentre.global_transform.origin - Vector3(0, playerbodyverticalheight - playerheadbodyradius, 0)
		if prevfootstepposition.distance_to(footstepposition) > footsteplength:
			footstepcount += 1
			prevfootsteptimestamp = physicsprocessTimeStamp
			prevfootstepposition = footstepposition

	var Dgo = playerMe.global_transform.origin
	var Dplayerbodycentre = HeadCentre.global_transform.origin - Vector3(0, playerheadcentreabovebodycentreheight, 0) + Ddebugvisualoffset

	var capsuleshaftheight = playerbodyverticalheight - 2*playerheadbodyradius
	$PlayerKinematicBody/PlayerBodyCapsule.shape.height = capsuleshaftheight

	if $PlayerKinematicBody/PlayerBodyCapsule/CapsuleShapePreview.visible:  # VVV this consumes 15ms!!!
		$PlayerKinematicBody/PlayerBodyCapsule/CapsuleShapePreview.mesh.mid_height = capsuleshaftheight
	
	if PlayerDirections.playerdirectedflight:
		process_directedflight(delta, PlayerDirections.playerdirectedflightvelocity)
	elif playerinfreefall:
		process_freefall(delta)
	else:
		var playerdirectedwalkmovement = Vector3(0,0,0)
		if PlayerDirections.playerdirectedwalkingvelocity != Vector3(0,0,0):
			playerdirectedwalkmovement = process_directedwalkmovement(delta, PlayerDirections.playerdirectedwalkingvelocity)
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

		

func process_feet_on_floor(delta, playerdirectedwalkmovement):
	playerbodycentre = HeadCentre.global_transform.origin - Vector3(0, playerheadcentreabovebodycentreheight, 0) + Ddebugvisualoffset
	var xxx = HeadCentre.global_transform.origin
	var xxx1 = xxx.y - playerheadcentreabovebodycentreheight	
	var xxxT = null
	
	var playeriscolliding = false
	var playerheadcolliding = false	
	var playerstartsfreefall = false

	var stepupdistanceclear = playermaxstepupheight
	var playerbodycapsulebasis = $PlayerKinematicBody/PlayerBodyCapsule.global_transform.basis
	var playerbodycentrewithdirectedmotion = playerbodycentre + Vector3(playerdirectedwalkmovement.x, 0, playerdirectedwalkmovement.z)
	psqparams.transform = Transform(playerbodycapsulebasis, playerbodycentrewithdirectedmotion + Vector3(0, stepupdistanceclear, 0))
	if len(get_world().direct_space_state.intersect_shape(psqparams, 1)) != 0:
		stepupdistanceclear = max(playermaxstepupheight*0.01, playerdirectedwalkmovement.y - playermaxstepupheight*0.02)
		psqparams.transform = Transform(playerbodycapsulebasis, playerbodycentrewithdirectedmotion + Vector3(0, stepupdistanceclear, 0))
		xxxT = psqparams.transform
		if len(get_world().direct_space_state.intersect_shape(psqparams, 1)) != 0:
			stepupdistanceclear = 0.05 # -playerstepdownbump
			psqparams.transform = Transform(playerbodycapsulebasis, playerbodycentrewithdirectedmotion + Vector3(0, stepupdistanceclear, 0))
			if len(get_world().direct_space_state.intersect_shape(psqparams, 1)) != 0:
				playeriscolliding = true
	
	if playeriscolliding and playerdirectedwalkmovement != Vector3(0,0,0) and Ddebugvisualoffset != Vector3(0,0,0):
		var ds = [ ]
		for i in range(1, 5):
			var dyy = playermaxstepupheight/20.0*i
			psqparams.transform = Transform(playerbodycapsulebasis, playerbodycentrewithdirectedmotion + Vector3(0, dyy, 0))
			if len(get_world().direct_space_state.intersect_shape(psqparams, 1)) == 0:
				ds.append(dyy)
		if len(ds) != 0:
			print("better stepup ", ds, playerdirectedwalkmovement.y)
			stepupdistanceclear = ds[0]
			playeriscolliding = false
		
	if not playeriscolliding and playerdirectedwalkmovement != Vector3(0,0,0):
		playerMe.global_transform.origin += Vector3(playerdirectedwalkmovement.x, 0, playerdirectedwalkmovement.z)
		playerbodycentre = playerbodycentrewithdirectedmotion
		assert (playerbodycentre.is_equal_approx(HeadCentre.global_transform.origin - Vector3(0, playerheadcentreabovebodycentreheight, 0) + Ddebugvisualoffset))
	
	var stepupdistance = 0.0
	if not playeriscolliding:
		if stepupdistanceclear > 0:
			var Dyyy = psqparams.transform
			var Dyyy1 = Transform(playerbodycapsulebasis, playerbodycentrewithdirectedmotion + Vector3(0, stepupdistanceclear, 0))

			var downcastdistance = stepupdistanceclear + playerstepdownbump
			var dropcollision = get_world().direct_space_state.cast_motion(psqparams, Vector3(0, -downcastdistance, 0))
			if len(dropcollision) != 0 and dropcollision[0] != 0.0:
				if dropcollision[0] == 1.0:
					playerstartsfreefall = gravityenabled
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
		var neworiginheight = playerbodycentre.y + playerheadcentreabovebodycentreheight - headcentreabovephysicalfloorheight
		playerMe.global_transform.origin.y = neworiginheight
		$PlayerKinematicBody.global_transform.origin = playerbodycentre
		if playerstartsfreefall:
			$PlayerKinematicBody/PlayerBodyCapsule/CapsuleShapePreview/FreefallWarning.visible = true
			playerfreefallbodyvelocity = getplayerrecentvelocity()
			playerinfreefall = true
		else:
			addplayervelocitystack((playerbodycentre - playerbodycentre_prev)/delta)
		playerbodycentre_prev = playerbodycentre
	else:
		resetplayervelocitystack(-2)
		var playerheadcentreforcollision = playerbodycentre + Vector3(0, playerheadcentreabovebodycentreheight, 0)
		psqparamshead.transform = Transform(playerbodycapsulebasis, playerheadcentreforcollision)
		playerheadcolliding = len(get_world().direct_space_state.intersect_shape(psqparamshead, 1)) != 0
		$PlayerHeadKinematicBody/PlayerHeadCapsule.global_transform.origin = playerheadcentreforcollision
		if Tglobal.soundsystem.quicksoundonpositionchange("GentleCollide", playerbodycentre, 0.15):
			if Ddebugvisualoffset != Vector3(0,0,0):
				var ds = [ ]
				for i in range(0, 8):
					var dyy = playermaxstepupheight/30.0*i
					psqparams.transform = Transform(playerbodycapsulebasis, playerbodycentre + Vector3(0, dyy, 0))
					var xxxTT = psqparams.transform
					if len(get_world().direct_space_state.intersect_shape(psqparams, 1)) == 0:
						ds.append([i,dyy,xxxTT])
				print("Height offsets that are clear: ", ds)

	$PlayerKinematicBody.global_transform.origin = playerbodycentre # + Vector3(0,0.03,0)
	$PlayerKinematicBody/PlayerBodyCapsule/CapsuleShapePreview/CollisionWarning.visible = playeriscolliding
	$PlayerKinematicBody/PlayerBodyCapsule/CapsuleShapePreview/HeadCollisionWarning.visible = playerheadcolliding
	HeadCollisionWarning.visible = playerheadcolliding
	
func endfreefallmode():
	resetplayervelocitystack(-1)
	playerinfreefall = false
	$PlayerKinematicBody/PlayerBodyCapsule/CapsuleShapePreview/FreefallWarning.visible = false
	
func process_freefall(delta):
	$PlayerKinematicBody.global_transform.origin = playerbodycentre
	var Dplayerbodycentre = playerbodycentre
	playerfreefallbodyvelocity.y -= gravityacceleration*delta
	playerfreefallbodyvelocity *= 1.0 - freefallairdragfactor*delta
	playerfreefallbodyvelocity = $PlayerKinematicBody.move_and_slide(playerfreefallbodyvelocity, Vector3(0, 1, 0))
	playerbodycentre = $PlayerKinematicBody.global_transform.origin
	playerMe.global_transform.origin = -Ddebugvisualoffset + playerbodycentre + Vector3(0, playerheadcentreabovebodycentreheight, 0) - headcentrefromvroriginvector
	var slidecount = $PlayerKinematicBody.get_slide_count()
	if slidecount > 0:
		var slidecollision = $PlayerKinematicBody.get_slide_collision(slidecount - 1)
		var slideincidence = -slidecollision.normal.dot(playerfreefallbodyvelocity)
		#print(playerbodycentre, slideincidence, playerfreefallbodyvelocity, freefallsurfaceslidedragfactor, " delta ", delta)
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
	if playerdirectedwalkingvelocity.dot(playerdirectedwalkmovement) > 0:
		var playerenlargedbodycentrewithdirectedmotion = playerbodycentre + Vector3(0, directedcollisionstepup, 0) + Vector3(playerdirectedwalkmovement.x, 0, playerdirectedwalkmovement.z)
		$PlayerEnlargedKinematicBody.global_transform.origin = playerenlargedbodycentrewithdirectedmotion
		var kinematiccollision = $PlayerEnlargedKinematicBody.move_and_collide(Vector3(0, -playermaxstepupheight, 0))
		var bumpup = playermaxstepupheight - (playerenlargedbodycentrewithdirectedmotion.y - $PlayerEnlargedKinematicBody.global_transform.origin.y)
		return Vector3(playerdirectedwalkmovement.x, bumpup, playerdirectedwalkmovement.z)
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
		if playerfreefallbodyvelocity.normalized().dot(playerdirectedflightvelocity.normalized()) < 0.86:
			pass # Tglobal.soundsystem.quicksoundonpositionchange("GlancingMotion", playerbodycentre + Vector3(0,3,0), 0)			
		playerbodycentre = $PlayerEnlargedKinematicBody.global_transform.origin
	playerMe.global_transform.origin = -Ddebugvisualoffset + playerbodycentre + Vector3(0, playerheadcentreabovebodycentreheight, 0) - headcentrefromvroriginvector
	addplayervelocitystack((playerbodycentre - playerbodycentre_prev)/delta)
	playerbodycentre_prev = playerbodycentre
	$PlayerKinematicBody.global_transform.origin = playerbodycentre


const fingeranglechange = cos(deg2rad(1))
const handanglechange = cos(deg2rad(2))
const handpositionchange = 0.01
const headanglechange = cos(deg2rad(4))
const headpositionchange = 0.01
const pointeranglechange = cos(deg2rad(1.2))
const pointerpositionchange = 0.015
const dtmin = 0.05
const dtmax = 0.8  # remotetimegap_dtmax?
var prevpositiondict = null
func transformwithinrange(trans0, trans1, poschange, cosangchange):
	var distorigin = trans0.origin.distance_to(trans1.origin)
	if distorigin > poschange:
		return false
	var q0 = trans0.basis.get_rotation_quat()
	var q1 = trans1.basis.get_rotation_quat()
	var dq = q0.inverse()*q1
	if dq.w < cosangchange:
		return false
	return true

func filter_playerhand_bandwidth(prevhand, hand):
	var boneorientationwithinrange = true
	if hand.has("boneorientations"):
		for i in range(len(hand["boneorientations"])):  # should use simply fingertip transforms
			var dq = prevhand["boneorientations"][i].inverse()*hand["boneorientations"][i]
			if dq.w < fingeranglechange:
				boneorientationwithinrange = false
				break
	if prevhand["valid"] == hand["valid"] and prevhand["triggerbuttonheld"] == hand["triggerbuttonheld"] and prevhand["gripbuttonheld"] == hand["gripbuttonheld"] \
			and boneorientationwithinrange and transformwithinrange(prevhand["transform"], hand["transform"], handpositionchange, handanglechange):
		hand.erase("transform")
		if hand.has("boneorientations"):
			hand.erase("boneorientations")
	else:
		prevhand["transform"] = hand["transform"]
		if hand.has("boneorientations"):
			prevhand["boneorientations"] = hand["boneorientations"].duplicate(true)
		prevhand["timestamp"] = hand["timestamp"]
		prevhand["triggerbuttonheld"] = hand["triggerbuttonheld"]
		prevhand["gripbuttonheld"] = hand["gripbuttonheld"]
		prevhand["valid"] = hand["valid"]
		return false
	return true
		
func filter_playerposition_bandwidth(positiondict):
	if prevpositiondict == null:
		prevpositiondict = positiondict.duplicate(true)
		return positiondict
	var dt = positiondict["timestamp"] - prevpositiondict["timestamp"]
	if dt < dtmin:
		return null
	if dt > dtmax:
		prevpositiondict = positiondict.duplicate(true)
		return positiondict
	if transformwithinrange(prevpositiondict["playertransform"], positiondict["playertransform"], headpositionchange, headanglechange):
		positiondict.erase("playertransform")
	else:
		prevpositiondict["playertransform"] = positiondict["playertransform"]
	if transformwithinrange(prevpositiondict["headcamtransform"], positiondict["headcamtransform"], headpositionchange, headanglechange):
		positiondict.erase("headcamtransform")
	else:
		prevpositiondict["headcamtransform"] = positiondict["headcamtransform"]

	if transformwithinrange(prevpositiondict["laserpointer"]["orient"], positiondict["laserpointer"]["orient"], pointerpositionchange, pointeranglechange) and abs(prevpositiondict["laserpointer"]["length"] - positiondict["laserpointer"]["length"]) < pointerpositionchange and prevpositiondict["laserpointer"]["spotvisible"] == positiondict["laserpointer"]["spotvisible"]:
		positiondict.erase("laserpointer")
	else:
		prevpositiondict["laserpointer"] = positiondict["laserpointer"].duplicate()

		
	if filter_playerhand_bandwidth(prevpositiondict["handleft"], positiondict["handleft"]):
		positiondict.erase("handleft")
	if filter_playerhand_bandwidth(prevpositiondict["handright"], positiondict["handright"]):
		positiondict.erase("handright")
	
	if not positiondict.has("playertransform") and not positiondict.has("headcamtransform") and not positiondict.has("handleft") and not positiondict.has("handright"):
		return null
	#prevpositiondict["timestamp"] = positiondict["timestamp"]
	return positiondict


func process_shareplayerposition():
	var doppelganger = playerMe.doppelganger
	if is_instance_valid(playerMe.doppelganger) or Tglobal.morethanoneplayer:
		var positiondict = playerMe.playerpositiondict()
		positiondict["footstepcount"] = footstepcount
		positiondict = filter_playerposition_bandwidth(positiondict)
		if positiondict != null:
			if Tglobal.morethanoneplayer:
				playerMe.rpc_unreliable("setavatarposition", positiondict)
			if is_instance_valid(playerMe.doppelganger):
				if positiondict.has("playertransform"):
					positiondict["playertransform"] = Transform(Basis(-positiondict["playertransform"].basis.x, positiondict["playertransform"].basis.y, -positiondict["playertransform"].basis.z), 
																Vector3(doppelganger.global_transform.origin.x, positiondict["playertransform"].origin.y, doppelganger.global_transform.origin.z))
				if playerMe.bouncetestnetworkID != 0:
					playerMe.rpc_unreliable_id(playerMe.bouncetestnetworkID, "bouncedoppelgangerposition", playerMe.networkID, positiondict)
				else:
					if positiondict.has("handright"):
						positiondict["handright"] = positiondict["handright"].duplicate(true)
					if positiondict.has("handleft"):
						positiondict["handleft"] = positiondict["handleft"].duplicate(true)
					doppelganger.setavatarposition(positiondict)

var bouldercount = 0
var bouldertimecountdown = 0
func _process(delta):
	if bouldercount > 0:
		bouldertimecountdown -= delta
		if bouldertimecountdown <= 0:
			bouldercount -= 1
			bouldertimecountdown = 0.1
			var HandRight = playerMe.get_node("HandRight")
			if HandRight.pointervalid:
				var handrightpointertrans = playerMe.global_transform*HandRight.pointerposearvrorigin
				var markernode = preload("res://nodescenes/MarkerNode.tscn").instance()
				var boulderclutter = get_node("/root/Spatial/BoulderClutter")
				var nc = boulderclutter.get_child_count()
				markernode.get_node("CollisionShape").scale = Vector3(0.4, 0.6, 0.4) if ((nc%2) == 0) else Vector3(0.2, 0.4, 0.2)
				markernode.global_transform.origin = handrightpointertrans.origin - 0.9*handrightpointertrans.basis.z
				markernode.linear_velocity = -5.1*handrightpointertrans.basis.z
				boulderclutter.add_child(markernode)

