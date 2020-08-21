extends Spatial

var networkID = 0

remote func setavatarposition(playertransform, headcamtransform, handlefttransform, handrighttransform, laserrotation, laserlength, laserspot):
	global_transform = playertransform
	$HeadCam.transform = headcamtransform
	$HandLeft.visible = (handlefttransform != null)
	if $HandLeft.visible:
		$HandLeft.transform = handlefttransform
	$HandRight.visible = (handrighttransform != null)
	if $HandRight.visible:
		$HandRight.transform = handrighttransform
		$HandRight/LaserOrient.rotation.x = laserrotation
		$HandRight/LaserOrient/Length.scale.z = laserlength
		$HandRight/LaserOrient/LaserSpot.translation.z = -laserlength
		$HandRight/LaserOrient/LaserSpot.visible = laserspot

puppet func bouncedoppelgangerposition(bouncebackID, playertransform, headcamtransform, handlefttransform, handrighttransform, laserrotation, laserlength, laserspot):
	get_parent().get_parent().playerMe.rpc_unreliable_id(bouncebackID, "setdoppelgangerposition", playertransform, headcamtransform, handlefttransform, handrighttransform, laserrotation, laserlength, laserspot)

puppet func setdoppelgangerposition(playertransform, headcamtransform, handlefttransform, handrighttransform, laserrotation, laserlength, laserspot):
	var doppelganger = get_parent().get_parent().playerMe.doppelganger
	if is_instance_valid(doppelganger):
		doppelganger.setavatarposition(playertransform, headcamtransform, handlefttransform, handrighttransform, laserrotation, laserlength, laserspot)

remotesync func playvoicerecording(wavrecording):
	print("playing recording ", wavrecording.size()) 
	var stream = AudioStreamSample.new()
	stream.format = AudioStreamSample.FORMAT_16_BITS
	stream.data = wavrecording
	stream.mix_rate = 44100
	stream.stereo = true
	$HandLeft/AudioStreamPlayer3D.stream = stream
	$HandLeft/AudioStreamPlayer3D.play()
