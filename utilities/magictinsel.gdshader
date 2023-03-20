// NOTE: Shader automatically converted from Godot Engine 4.0.stable's StandardMaterial3D.

shader_type spatial;
render_mode skip_vertex_transform,blend_mix,depth_draw_opaque,cull_disabled,diffuse_burley,specular_schlick_ggx,unshaded;

uniform vec4 albedo;
uniform float point_size;
uniform sampler2D position_noise;

const float streamrad = 3.0; 
const float sparkrad = 0.2; 
const float sparktrailrad = 0.1; 

void vertex() {
	float growtimefac = COLOR.r; 
	float timefac = COLOR.r; 
	float springoutfac = 1.0 - pow(1.0 - timefac, 3.0); 
	float noisetimefac = (timefac*timefac*0.5 - timefac + 1.0); 
	float UVycollapsed = (UV.y > 0.5 ? 0.6 : UV.y*1.0); 
	if (UV.y < 0.3)  UVycollapsed *= 1.2;  

	float noisedisplacement = springoutfac*7.4*pow(UVycollapsed, 3.0); 
	float fadetimefac = COLOR.g; 

	float noiserow = min(UV.y, 0.6); 
	float prevnoiserow = max(noiserow - 0.2, 0.0); 
	vec4 normnoise = texture(position_noise, vec2(noisetimefac, noiserow)); 
	VERTEX.xyz += vec3((normnoise.x-0.4)*noisedisplacement, (normnoise.z-0.99)*noisedisplacement, (normnoise.y-0.4)*noisedisplacement); 
	VERTEX.y += UVycollapsed*streamrad*springoutfac; 

    VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;

	vec2 streamvec = normalize((MODELVIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xy); 
	vec2 perpstreamvec = vec2(streamvec.y, -streamvec.x); 
	float aspect = length(PROJECTION_MATRIX[1].xyz)/length(PROJECTION_MATRIX[0].xyz); 
	if (UV.y > 0.75) {
		VERTEX.xy += ((UV.x - 0.5)*perpstreamvec + (UV.y - 0.9)*5.0*streamvec)*sparkrad; 
	} else {
		VERTEX.xy += (UV.x - 0.5)*perpstreamvec*sparktrailrad; 
	}
}

void fragment() {
	float duv; 
	if ((UV.y >= 0.6) && (UV.y <= 0.8))
		discard; 
	else if (UV.y >= 0.8)
		duv = distance(vec2(UV.x, (UV.y - 0.8)*5.0), vec2(0.5)); 
	else 
		duv = length(vec2(UV.x - 0.5, (UV.y - 0.3)/0.6*0.7)); 
	//else if (UV.y >= 0.6)
	//	discard; 
	
	float circle = 0.1 * 3.0 / duv;
	float centerCircle = 0.1 * 3.0 / duv;

	float clip = 1.0 - smoothstep(0.01, 0.5, duv);
	float centerClip = 1.0 - smoothstep(0.0001, 0.1, duv);

	vec3 color = vec3(circle) * clip * vec3(0.1, 0.5, 0.1);
	vec3 centerColor = vec3(centerCircle) * centerClip;
    ALBEDO = min(vec3(1.0), color + centerColor);
	if (UV.y >= 0.8) {
		ALBEDO = vec3(0.8, 0.2, 0.4)*0.7/(duv + 0.04) - vec3(1.0); 
		ALPHA = 0.4 - duv; 
	} else {
		ALBEDO = vec3(0.2, 0.8, 0.4)*0.7/(duv + 0.03) - vec3(0.7); 
		ALPHA = 0.4 - duv; 
	}
	float fadeperiod = UV.y*UV.y*0.2 + 0.01;  
	if (COLOR.r > 1.0 - fadeperiod)
		ALPHA *= (1.0 - COLOR.r)/fadeperiod; 
	//ALPHA = 1.0; 
}
