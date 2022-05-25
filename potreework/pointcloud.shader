shader_type spatial;
render_mode world_vertex_coords,shadows_disabled;

uniform float point_scale = 16.0;
uniform vec3 highlightplaneperp = vec3(0,1,0);
uniform float highlightplanedot = 0.0;
uniform mat4 roottransforminverse = mat4(1.0); 
uniform vec3 ocellcentre = vec3(0,0,0);
uniform int ocellmask = 0;
uniform float colormixweight = 0.5; 

const vec3 closecol = vec3(1,0,0);
const vec3 farcol = vec3(0,0,1);
const float fardist = 30.0;
const float fardisttaper = 20.0;
const float fardisttaperfac = -(fardisttaper*((fardisttaper + fardist)))/fardist;

uniform vec3 highlightcol = vec3(1,1,0);
uniform vec3 highlightcol2 = vec3(0,1,1);
uniform float highlightdist = 0.5;

const vec3 bordercolor = vec3(0.1, 0.1, 0.2);
const float edgeborder = 0.5 - 0.05; 
const float closenessdist = 0.8;


varying vec3 emissioncol;
varying vec3 bordercol; 
varying float edgebord; 
varying float closenessfrac;

void vertex() {
	float distcamera = length(CAMERA_MATRIX[3].xyz - VERTEX); 
	POINT_SIZE = point_scale/distcamera;

	vec4 sv = roottransforminverse*vec4(VERTEX, 1.0); 
	int ocellindex = (sv.x > ocellcentre.x ? 16 : 1) * 
					 (sv.y > ocellcentre.y ? 4 : 1) * 
					 (sv.z > ocellcentre.z ? 2 : 1); 
	if (((ocellmask / ocellindex) % 2) != 0) {
		POINT_SIZE = 0.0;
		// should return here but causes points to blip purple if these other values aren't set
	}

	NORMAL = CAMERA_MATRIX[2].xyz;

	float distplane = dot(VERTEX, highlightplaneperp) - highlightplanedot; 
	float emissionfac = clamp(1.0 - abs(distplane)/highlightdist, 0.0, 1.0);
	emissioncol = (distplane > 0.0 ? highlightcol : highlightcol2)*emissionfac;
	
	float mixval = (1.0/(distcamera + fardisttaper) - 1.0/fardisttaper)*fardisttaperfac;
	vec3 distancecolor = mix(closecol, farcol, mixval);
	COLOR.rgb = mix(distancecolor, COLOR.rgb, colormixweight);
	
	float fadeoutfac = (POINT_SIZE-8.0)/16.0;
	bordercol = mix(bordercolor, vec3(1.0, 1.0, 1.0), clamp(1.0 - fadeoutfac, 0.0, 1.0));
	edgebord = edgeborder*clamp((fadeoutfac+1.0)/2.0, 0.3, 1.0); 
	
	closenessfrac = 1.0 - distcamera/closenessdist;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	EMISSION = emissioncol;
	float squarecentredist = max(abs(POINT_COORD.x-0.5), abs(POINT_COORD.y-0.5)); 
	
	float rsq = (POINT_COORD.x-0.5)*(POINT_COORD.x-0.5) + (POINT_COORD.y-0.5)*(POINT_COORD.y-0.5);
	if (rsq > 0.25+point_scale*0.002) 
		discard;

	ALBEDO *= mix(vec3(1.0, 1.0, 1.0), bordercolor, rsq*3.0);
	if (closenessfrac > 0.0) {
		if ((abs(POINT_COORD.x*2.0-1.0) < closenessfrac) || (abs(POINT_COORD.y*2.0-1.0) < closenessfrac))
			discard; 
	}
}
