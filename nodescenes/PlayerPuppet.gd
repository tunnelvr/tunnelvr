extends Spatial

var networkID = 0

remote func setavatarposition(positiondict):
	global_transform = positiondict["playertransform"]
	$HeadCam.transform = positiondict["headcamtransform"]
	$HandLeft.visible = (positiondict["handlefttransform"] != null)
	if $HandLeft.visible:
		$HandLeft.transform = positiondict["handlefttransform"]
	$HandRight.visible = (positiondict["handrighttransform"] != null)
	if $HandRight.visible:
		$HandRight.transform = positiondict["handrighttransform"]
		$HandRight/LaserOrient.rotation.x = positiondict["laserrotation"]
		$HandRight/LaserOrient/Length.scale.z = positiondict["laserlength"]
		$HandRight/LaserOrient/LaserSpot.translation.z = -positiondict["laserlength"]
		$HandRight/LaserOrient/LaserSpot.visible = positiondict["laserspot"]

puppet func bouncedoppelgangerposition(bouncebackID, positiondict):
	get_parent().get_parent().playerMe.rpc_unreliable_id(bouncebackID, "setdoppelgangerposition", positiondict)

puppet func setdoppelgangerposition(playertransform, positiondict):
	var doppelganger = get_parent().get_parent().playerMe.doppelganger
	if is_instance_valid(doppelganger):
		doppelganger.setavatarposition(positiondict)

remotesync func playvoicerecording(wavrecording):
	print("playing recording ", wavrecording.size()) 
	var stream = AudioStreamSample.new()
	stream.format = AudioStreamSample.FORMAT_16_BITS
	stream.data = wavrecording
	stream.mix_rate = 44100
	stream.stereo = true
	$HandLeft/AudioStreamPlayer3D.stream = stream
	$HandLeft/AudioStreamPlayer3D.play()
