shader_type canvas_item;

uniform sampler2D height_map;
uniform float uv_scale;
uniform float sample_size;
uniform vec3 target_position;

void fragment() {

	//var height_map_center_pos_uv : Vector2 = (Vector2(fposmod(pos.x * height_map_uv_scale, height_map_size.x), fposmod(-pos.z * height_map_uv_scale, height_map_size.y)) / height_map_size)
	ivec2 height_map_size = textureSize(height_map, 0);
	float height_incr = 1.0/float(height_map_size.x);
	float sample_incr = sample_size * height_incr;

	float pointX = (target_position.x / float(height_map_size.x)) * uv_scale;
	float pointY = (-target_position.z / float(height_map_size.y)) * uv_scale;
	vec2 target_position_uv = vec2(pointX, pointY);
	//vec2 offsetXY = vec2(height_incr * 0.0, height_incr * 0.0);

	//vec2 uvw_new = vec2(mod(UV.x + pointX + 0.5, 1.0), mod(UV.y + pointY + 0.5, 1.0));
	vec2 uvw_new = target_position_uv + (UV * sample_incr) - vec2(sample_incr*0.5);
	vec2 offsetXY = vec2(height_incr * 0.5, height_incr * 0.5);
	uvw_new = mod(uvw_new + offsetXY, 1.0);
	float height = textureLod(height_map, uvw_new, 0.0).x;

	COLOR = vec4(vec3(height), 1.0);
	if((UV.x < 0.505 && UV.x >= 0.495) && (UV.y < 0.505 && UV.y > 0.495)) {
	//if(UV.x < 0.005 && UV.y < 0.005) {
		COLOR = vec4(1.0, 0.0, 0.0, 1.0);
	}
	//COLOR = vec4(1.0, 0.5, 0.2, 1.0);
}
