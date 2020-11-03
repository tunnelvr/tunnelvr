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
	CL_PlayerHotspot	=0b00001000000000,
	CL_Papersheet		=0b00010000000000,
	
	CLV_MainRayAll		=0b00000011111000,
	CLV_MainRayXC		=0b00000000011000,
	CLV_PlanRayAll		=0b00000101111000,
	CLV_PlanRayNoTube	=0b00000100011000
}
			
enum {
	VL_default							= 0b0000000000000001,
	VL_uioverlays						= 0b0000000000000010,
	VL_floortextures					= 0b0000000000000100,
	VL_xcdrawingnodes					= 0b0000000000001000,
	VL_xcdrawinglines					= 0b0000000000010000,
	VL_xctubelines						= 0b0000000000100000,
	VL_xctubeposlines					= 0b0000000001000000,
	VL_xctubenodes						= 0b0000000010000000,
	VL_xcshells							= 0b0000000100000000,
	VL_centrelinestations				= 0b0000001000000000,
	VL_centrelinestationsplanview		= 0b0000010000000000,
	VL_surveylegs						= 0b0000100000000000,
	VL_overheadlight					= 0b0001000000000000,
	VL_centrelinestationslabel			= 0b0010000000000000,
	VL_floortextureplanview				= 0b0100000000000000,
	VL_centrelinestationslabelplanview	= 0b1000000000000000,

	VLCM_PlanViewCamera 				= 0b1111110111111011,
	VLCM_PlanViewCameraNoTube			= 0b1101110011111011
}
