class_name DRAWING_TYPE

enum { DT_XCDRAWING 	= 0, 
	   DT_FLOORTEXTURE 	= 1, 
	   DT_CENTRELINE 	= 2, 
	   DT_PAPERTEXTURE 	= 3, 
	   DT_PLANVIEW 		= 4 }

enum { VIZ_XCD_HIDE 				= 0
	   VIZ_XCD_PLANE_VISIBLE 		= 1,
	   VIZ_XCD_NODES_VISIBLE 		= 2,
	   VIZ_XCD_PLANE_AND_NODES_VISIBLE = 3,
	
	   VIZ_XCD_FLOOR_NORMAL 		= 0b001000,
	   VIZ_XCD_FLOOR_ACTIVE_B 		= 0b000001,
	   VIZ_XCD_FLOOR_NOSHADE_B 		= 0b000010,
	   VIZ_XCD_FLOOR_HIDDEN 		= 0b010000,
	   VIZ_XCD_FLOOR_DELETED 		= 0b010001
	 }
