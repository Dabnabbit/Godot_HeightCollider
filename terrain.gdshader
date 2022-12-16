shader_type spatial;

render_mode world_vertex_coords;
//render_mode world_vertex_coords, diffuse_toon, specular_toon;

uniform bool _debug_shader_enable = false;
uniform bool _debug_show_height = false;
uniform bool _debug_show_normals = false;
uniform float _debug_flat_shade : hint_range(0.0, 1.0) = 0.0;

uniform sampler2D diffuse_map : source_color;
uniform sampler2D height_map : hint_default_black;
uniform sampler2D normal_map : hint_normal;
uniform float normal_scale_frag : hint_range(0.0, 1.0) = 0.0;
uniform float normal_scale_texture : hint_range(0.0, 1.0) = 0.0;
uniform float normal_smoothing = 1.0;
//uniform float height_scale : hint_range(0.0,128.0) = 1.0;
uniform float height_scale = 1.0;
uniform float height_offset = 0.0;
uniform float uv_scale = 1.0;

uniform float horizon_power = 0.0;
uniform float horizon_start = 500.0;
uniform float horizon_end = 5000.0;

uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.0;

uniform vec3 target_position;

//varying flat vec3 vertex_position; //- Use this technique to make pixelated flat shaded normals!
varying smooth vec3 vertex_position;
varying vec3 vertex_normal;
varying float vertex_height;

vec3 xform(mat4 matrix, vec3 position, const float w){
	return (matrix * vec4(position, w)).xyz;
}

vec4 sample_texture(sampler2D texture_map, vec3 position) {
	vec2 size = vec2(textureSize(texture_map, 0));
	vec2 scale = size / (uv_scale*2.0);

	mat4 terrainToWorld = mat4(1);
	terrainToWorld[0] *= scale.x*2.0;
	terrainToWorld[1] *= height_scale;
	terrainToWorld[2] *= scale.y*2.0;
	terrainToWorld[3].xyz = vec3(-scale.x,0,-scale.y);

	position = xform(inverse(terrainToWorld), position, 1.0);
	vec4 pixel = textureLod(texture_map, position.xz, 0);
	return pixel;
}

vec4 sample_texture2(sampler2D texture_map, vec3 position) {
	vec2 size = vec2(textureSize(texture_map, 0));
	vec2 scale = size / (uv_scale*2.0);

	mat4 terrainToWorld = mat4(1);
	terrainToWorld[0] *= scale.x*2.0;
	terrainToWorld[1] *= height_scale;
	terrainToWorld[2] *= scale.y*2.0;
	terrainToWorld[3].xyz = vec3(-scale.x,0,-scale.y);

	position = xform(inverse(terrainToWorld), position, 1.0);
	vec4 pixel = textureLod(texture_map, position.xz, 0);
	float epsilon = 0.0005;
	vec4 pixel2 = textureLod(texture_map, position.xz + vec2(-epsilon, 0), 0);
	vec4 pixel3 = textureLod(texture_map, position.xz + vec2(epsilon, 0), 0);
	vec4 pixel4 = textureLod(texture_map, position.xz + vec2(0, -epsilon), 0);
	vec4 pixel5 = textureLod(texture_map, position.xz + vec2(0, epsilon), 0);
	//return (pixel + ((pixel2 + pixel3 + pixel4 + pixel5) * 0.25))*0.5;
	//return (pixel2 + pixel3 + pixel4 + pixel5) * 0.25;
	return (pixel + pixel2 + pixel3 + pixel4 + pixel5) * 0.2;
}
vec3 sample_normal(vec3 position) {
	float epsilon = normal_smoothing;
	float sample_left = sample_texture(height_map, position + vec3(-epsilon, 0, 0)).x * height_scale;
	float sample_right = sample_texture(height_map, position + vec3(epsilon, 0, 0)).x * height_scale;
	float sample_up = sample_texture(height_map, position + vec3(0, 0, -epsilon)).x * height_scale;
	float sample_down = sample_texture(height_map, position + vec3(0, 0, epsilon)).x * height_scale;
	vec2 g = vec2(sample_right-sample_left, sample_down-sample_up) / epsilon; //-Four Samples, difference across point
	vec3 normals = normalize(vec3(-g.x, 1.0, -g.y));
	return normals;
}

vec3 sample_normal2(vec3 position) {
	float epsilon = normal_smoothing;
	float sample_left = sample_texture2(height_map, position + vec3(-epsilon, 0, 0)).x * height_scale;
	float sample_right = sample_texture2(height_map, position + vec3(epsilon, 0, 0)).x * height_scale;
	float sample_up = sample_texture2(height_map, position + vec3(0, 0, -epsilon)).x * height_scale;
	float sample_down = sample_texture2(height_map, position + vec3(0, 0, epsilon)).x * height_scale;
	vec2 g = vec2(sample_right-sample_left, sample_down-sample_up) / epsilon; //-Four Samples, difference across point
	vec3 normals = normalize(vec3(-g.x, 1.0, -g.y));
	return normals;
}

vec3 unpack_normalmap(vec4 rgba) {
	vec3 result = rgba.xzy * 2.0 - vec3(1.0);
	result.xz *= -1.0;
	//result.y *= -1.0;
	return result;
}

void vertex() {
	vertex_position = VERTEX;
	vec3 half_pixel = vec3(0.0, 0, 0.0);
	half_pixel = vec3(0.5, 0, 0.5);
	vertex_height = sample_texture(height_map, vertex_position + half_pixel).x * height_scale;
	NORMAL = sample_normal2(vertex_position + half_pixel);
	VERTEX.y = vertex_height - height_offset;
	vertex_normal = NORMAL;
	vertex_position = VERTEX + half_pixel;

	//---------------------------------------------------------------------------------
	//- HORIZON DEFORM
	float dist = max(distance((vertex_position + half_pixel).xz, target_position.xz),0.0001);
	float power = horizon_power;
	float negate = 1.0;
	//VERTEX.y -= smoothstep(horizon_start, horizon_end, dist)*pow(1.0+(horizon_power*0.01),dist);
	//- Apparently 0^0 fails to return a value, so don't use that...
	if(power < 0.0) {
		power *= -1.0;
		negate *= -1.0;
	}
	VERTEX.y -= negate * smoothstep(horizon_start, max(horizon_end, horizon_start), dist)*pow(dist, power);
}

void fragment() {
//	float dist = clamp(distance((vertex_position).xz, target_position.xz) * 0.0005, 0.0, 1.0);
	vec3 normals_frag = sample_normal(vertex_position);
	normals_frag = xform(VIEW_MATRIX, normals_frag, 0.0).xyz;
	//NORMAL = mix(NORMAL, normals_frag, dist);
	NORMAL = mix(NORMAL, normals_frag, normal_scale_frag);

	vec3 normals_texture = mat3(1.0) * unpack_normalmap(sample_texture(normal_map, vertex_position));
	normals_texture = normalize(normals_texture);
	normals_texture = xform(VIEW_MATRIX, normals_texture, 0.0).xyz;
	NORMAL = mix(NORMAL, normals_texture.rgb, normal_scale_texture);
	vec3 point = xform(VIEW_MATRIX, vertex_position, 1.0);
	vec3 normals_flat = normalize(cross(dFdy(point), dFdx(point)));
	if(SCREEN_UV.x < _debug_flat_shade){
		NORMAL = normals_flat;
	}

	vec4 diffuse = sample_texture(diffuse_map, vertex_position);
	ALBEDO = diffuse.rgb;
	if(_debug_show_height) {
		ALBEDO = vec3(vertex_height / height_scale);
	}
	if(_debug_show_normals) {
		ALBEDO = NORMAL;
	}
	if(_debug_shader_enable) {
		ALBEDO *= COLOR.rgb;
	}
	ALBEDO *= 0.1;
	//SPECULAR = 0.0;
	METALLIC = metallic;
 	ROUGHNESS = roughness;
	RIM = 0.0;
	RIM_TINT = 0.5;
}