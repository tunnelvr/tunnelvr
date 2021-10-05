shader_type spatial;
render_mode world_vertex_coords,shadows_disabled;

uniform float point_scale = 16.0;
uniform vec3 highlightplaneperp = vec3(0,1,0);
uniform float highlightplanedot = 0.0;
uniform mat4 roottransforminverse = mat4(1.0); 
uniform vec3 ocellcentre = vec3(0,0,0);
uniform int ocellmask = 0;

const vec3 closecol = vec3(1,0,0);
const vec3 farcol = vec3(0,0,1);
const float fardist = 20.0;
const vec3 highlightcol = vec3(1,1,0);
const vec3 highlightcol2 = vec3(0,1,1);
const float highlightdist = 0.5;
const float sizebumpdist = 0.25;
const vec3 bordercolor = vec3(0.1, 0.1, 0.2);
const float edgeborder = 0.5 - 0.05; 

varying vec3 emissioncol;
varying vec3 bordercol; 
varying float edgebord; 

void vertex() {
	float distcamera = length(CAMERA_MATRIX[3].xyz - VERTEX); 
	POINT_SIZE = point_scale/distcamera;
	vec4 sv = roottransforminverse*vec4(VERTEX, 1.0); 
	int ocellindex = (sv.x > ocellcentre.x ? 16 : 1) * 
					 (sv.y > ocellcentre.y ? 4 : 1) * 
					 (sv.z > ocellcentre.z ? 2 : 1); 
	if (((ocellmask / ocellindex) % 2) != 0)
		POINT_SIZE = 0.0;

	NORMAL = CAMERA_MATRIX[2].xyz;
	float distplane = dot(VERTEX, highlightplaneperp) - highlightplanedot; 
	if (abs(distplane) < sizebumpdist) {
		POINT_SIZE *= 2.0;
	}
	COLOR.rgb = mix(closecol, farcol, distcamera/fardist);
	float emissionfac = clamp(1.0 - abs(distplane)/highlightdist, 0.0, 1.0);
	emissioncol = (distplane > 0.0 ? highlightcol : highlightcol2)*emissionfac;
	float fadeoutfac = (POINT_SIZE-8.0)/16.0;
	bordercol = mix(bordercolor, vec3(1.0, 1.0, 1.0), clamp(1.0 - fadeoutfac, 0.0, 1.0));
	edgebord = edgeborder*clamp((fadeoutfac+1.0)/2.0, 0.7, 1.0); 
}

void fragment() {
	ALBEDO = COLOR.rgb;
	EMISSION = emissioncol;
	float squarecentredist = max(abs(POINT_COORD.x-0.5), abs(POINT_COORD.y-0.5)); 
	if (squarecentredist > edgebord)
		ALBEDO *= bordercol;
		
	// circular points
	//float rsq = (POINT_COORD.x-0.5)*(POINT_COORD.x-0.5) + (POINT_COORD.y-0.5)*(POINT_COORD.y-0.5);
	//if (rsq > 0.25)  discard;
}