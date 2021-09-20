shader_type spatial;
render_mode world_vertex_coords,shadows_disabled;

uniform vec4 albedo : hint_color = vec4(1.0);
uniform float point_scale = 16.0;
uniform vec3 highlightplaneperp = vec3(0,1,0);
uniform float highlightplanedot = 0.0;
uniform vec3 ocellcentre = vec3(0,0,0);
uniform int ocellmask = 0;

const vec3 closecol = vec3(1,0,0);
const vec3 farcol = vec3(0,0,1);
const float fardist = 20.0;
const vec3 highlightcol = vec3(1,1,0);
const float highlightdist = 0.5;
const float sizebumpdist = 0.25;

void vertex() {
	float distcamera = length(CAMERA_MATRIX[3].xyz - VERTEX); 
	POINT_SIZE = point_scale/distcamera;
	int ocellindex = (VERTEX.x > ocellcentre.z ? 2 : 1) * 
					 (VERTEX.y > ocellcentre.y ? 4 : 1) * 
					 (VERTEX.z > ocellcentre.x ? 16 : 1); 
	if (((ocellmask / ocellindex) % 2) != 0)
		POINT_SIZE = 0.0;

	NORMAL = CAMERA_MATRIX[2].xyz;
	float distplane = abs(dot(VERTEX, highlightplaneperp) - highlightplanedot); 
	if (distplane < sizebumpdist) {
		POINT_SIZE *= 2.0;
	}
	COLOR.rgb = mix(closecol, farcol, distcamera/fardist);
	COLOR.a = clamp(1.0 - distplane/highlightdist, 0.0, 1.0);
}

void fragment() {
	ALBEDO = COLOR.rgb * albedo.rgb;
	EMISSION = highlightcol*COLOR.a; 
}