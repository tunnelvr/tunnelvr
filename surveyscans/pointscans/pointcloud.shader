shader_type spatial;
render_mode world_vertex_coords;
uniform vec4 albedo : hint_color = vec4(1.0);
uniform float point_scale = 64.0;

void vertex() {
	// Point size adjustment using camera position
	float dist = length(CAMERA_MATRIX[3].xyz - VERTEX); //Getting distance between camera and the vertices
	//float vpratio = (VIEWPORT_SIZE.x / VIEWPORT_SIZE.y); //Get viewport size ratio
	//POINT_SIZE = (point_scale*vpratio)/dist * vpratio; //Adjust point size
	//NORMAL = VERTEX - WORLD_MATRIX[3].xyz;
	POINT_SIZE = point_scale/dist;
	NORMAL = CAMERA_MATRIX[2].xyz;
	
	// uncomment to work from distance
	COLOR.rgb = mix(vec3(1,0,0), vec3(0,0,1), dist/20.0);
}

void fragment() {
	// use vertex color as albedo
	ALBEDO = COLOR.rgb * albedo.rgb;
}