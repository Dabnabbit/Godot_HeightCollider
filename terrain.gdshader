shader_type spatial;
render_mode world_vertex_coords;
//render_mode world_vertex_coords, diffuse_toon;
//render_mode world_vertex_coords, diffuse_toon, specular_toon;

//uniform bool test_horizon = false;
uniform sampler2D diffuse_map;
uniform sampler2D height_map;
uniform sampler2D normal_map : hint_normal;
uniform bool normal_enable_vert = true;
uniform float normal_frag_scale : hint_range(0.0, 1.0) = 1.0;
uniform float uv_scale = 1.0;
uniform float height_scale = 1.0;
uniform float height_offset = 0.0;

uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.025;

uniform vec3 target_position;

uniform bool _debug_shader_enable = false;
uniform bool _diffuse_color_blend = false;

uniform mat3 normal_basis;

//uniform sampler2D normal_map;
varying vec3 vertex_position;
varying vec3 vertex_normals;
//varying vec3 pixel_normals;
varying float height;
varying vec3 vertex_color;

vec3 unpack_normalmap(vec4 rgba) {
	vec3 result = rgba.xzy * 2.0 - vec3(1.0);
	//result *= -1.0;
	return result;
}

vec3 getNormal(vec2 uv, float texelSize) {
	float t = texture(height_map, uv + vec2(texelSize * vec2(0.0, -1.0))).r * height_scale;
	float r = texture(height_map, uv + vec2(texelSize * vec2(1.0, 0.0))).r * height_scale;
	float l = texture(height_map, uv + vec2(texelSize * vec2(-1.0, 0.0))).r * height_scale;
	float b = texture(height_map, uv + vec2(texelSize * vec2(0.0, 1.0))).r * height_scale;
	
	//return -normalize(vec3(2.0 * (r - l), 2.0 * (b - t), -4.0));
	return -normalize(vec3((r - l), (b - t),-1.0));
}

void vertex() {
	//vertex_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vertex_position = VERTEX.xyz;
	
	ivec2 height_map_size = textureSize(height_map, 0);
	float height_incr = 1.0/float(height_map_size.x);
	
	float pointX = (vertex_position.x / float(height_map_size.x)) * uv_scale;
	float pointY = (-vertex_position.z / float(height_map_size.y)) * uv_scale;
	vec2 pointXY = vec2(pointX, pointY);
	vec2 offsetXY = vec2(height_incr * 0.5, height_incr * 0.5);
	
	height = textureLod(height_map, pointXY + offsetXY, 0.0).x;
	//VERTEX.y += (height * height_scale) - ((height_scale * 0.5) + height_offset);
	VERTEX.y += (height * height_scale) - (height_offset);
	vertex_position = VERTEX.xyz;
	//---------------------------------------------------------------------------------
	//- NORMALS
	//NORMAL = getNormal(UV, height_incr);
	NORMAL = getNormal(pointXY, 1.0 / float(textureSize(height_map, 0).x));
}


void fragment() {
	ivec2 height_map_size = textureSize(height_map, 0);
	ivec2 diffuse_map_size = textureSize(diffuse_map, 0);
	ivec2 normal_map_size = textureSize(normal_map, 0);
	vec2 height_incr = 1.0/vec2(height_map_size);
	vec2 diffuse_incr = 1.0/vec2(diffuse_map_size);
	vec2 normal_incr = 1.0/vec2(normal_map_size);
	vec2 pointXY_height = vertex_position.xz * height_incr * uv_scale; //- Multiplied the new vertex/pixel position by the heightmap increment (pixel ratio), multiplied by uniform UV scale
	vec2 pointXY_diffuse = vertex_position.xz * diffuse_incr * uv_scale;
	vec2 pointXY_normals = vertex_position.xz * normal_incr * uv_scale; //- Multiplied the new vertex/pixel position by the heightmap increment (pixel ratio), multiplied by uniform UV scale
	pointXY_height.y *= -1.0; //- Gotta flip the Z axis because Godot, which is now the Y axis in 2D
	pointXY_diffuse.y *= -1.0; //- Gotta flip the Z axis because Godot, which is now the Y axis in 2D
	pointXY_normals.y *= -1.0; //- Gotta flip the Z axis because Godot, which is now the Y axis in 2D

	//vec3 pixel_normals = normal_basis * unpack_normalmap(texture(normal_map, pointXY_normals));
	vec3 pixel_normals = normal_basis * unpack_normalmap(texture(normal_map, UV));
	pixel_normals = normalize(pixel_normals);
	pixel_normals = (VIEW_MATRIX * (vec4(pixel_normals,0.0))).xyz;
	//NORMAL = normalize(NORMAL + pixel_normals.rgb);
	//NORMAL = mix(NORMAL, pixel_normals.rgb, normal_frag_scale);
//	NORMAL = pixel_normals.rgb;

	//crossdFdx(pointXY_normals)

	ALBEDO = texture(diffuse_map, pointXY_diffuse).xyz;
	if(_diffuse_color_blend) {
		ALBEDO = mix(vec3(0.5), texture(height_map, pointXY_height).xyz,1.0);
		ALBEDO *= mix(vec3(0.9,0.8,0.8), vec3(0.2,0.9,0.0), smoothstep(-0.5, 10.0, vertex_position.y));
	}
	if(_debug_shader_enable) {
		ALBEDO *= vertex_color;
	}
	ALBEDO *= 0.1;
	//ALBEDO = vertex_normals;
	//ALBEDO = vec3(0.5);
	//ALPHA = 1.0;
	METALLIC = metallic;
 	ROUGHNESS = roughness;
	RIM = 0.0;
	RIM_TINT = 0.5;
}
