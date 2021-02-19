class_name CollisionLayer

# See Project->Settings->Layers->3D Physics
enum { 
	CL_Player			=0b00000000000001,
	CL_Environment		=0b00000000000010,
	CL_Objects			=0b00000000000100,
	CL_Pointer			=0b00000000001000,
	CL_PointerFloor		=0b00000000010000,
	CL_CaveWall			=0b00000000100000,
	CL_CaveWallTrans	=0b00000001000000,
	CL_CentrelineStation=0b00000010000000,
	CL_CentrelineStationPlanView \
						=0b00000100000000,
	CL_PlayerHotspot	=0b00010000000000,
	CL_Papersheet		=0b00100000000000,
	CL_IntermediatePlane=0b01000000000000,
	
	CLV_MainRayAll		=0b01000011111000,
	CLV_MainRayXC		=0b01000000011000,
	CLV_MainRayAllNoCentreline \
						=0b01000001111000,

	CLV_PlanRayAll		=0b00000101111000,
	CLV_PlanRayNoCentreline \
						=0b00000001111000,
	CLV_PlanRayNoTube	=0b00000100011000
}
			
enum {
	VL_default							= 0b00000000000000000001,
	VL_uioverlays						= 0b00000000000000000010,
	VL_floortextures					= 0b00000000000000000100,
	VL_xcdrawingnodes					= 0b00000000000000001000,
	VL_xcdrawinglines					= 0b00000000000000010000,
	VL_xctubelines						= 0b00000000000000100000,
	VL_xctubeposlines					= 0b00000000000001000000,
	VL_xctubenodes						= 0b00000000000010000000,
	VL_xcshells							= 0b00000000000100000000,
	VL_centrelinestations				= 0b00000000001000000000,
	VL_centrelinestationsplanview		= 0b00000000010000000000,
	VL_positioningnodelines				= 0b00000000100000000000, # obsolete: now is VL_xctubeposlines
	VL_overheadlight					= 0b00000001000000000000,
	VL_centrelinestationslabel			= 0b00000010000000000000,
	VL_floortextureplanview				= 0b00000100000000000000,
	VL_centrelinestationslabelplanview	= 0b00001000000000000000,
	VL_centrelinedrawinglines			= 0b00010000000000000000,
	VL_centrelinedrawinglinesplanview	= 0b00100000000000000000,
	
	VLCM_PlanViewCamera 				= 0b00101111110111111011,
	VLCM_PlanViewCameraNoTube			= 0b00101101110001001011
	VLCM_PlanViewCameraNoCentreline		= 0b00000111000111111011,

	VLCM_PlayerCamera					= 0b00010111101111111111,
	VLCM_PlayerCameraNoCentreline		= 0b00000111000110111111,
}
