extends Spatial

remote func setavatarposition(playertransform, headcamtransform, handlefttransform, handrighttransform):
	#print("ppt ", playertransform.origin.x, " ", headcamtransform.origin.x)
	global_transform = playertransform
	$HeadCam.transform = headcamtransform
	$HandLeft.transform = handlefttransform
	$HandRight.transform = handrighttransform

