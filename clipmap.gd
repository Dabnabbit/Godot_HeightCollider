@tool

extends Node3D

@export @onready var _clipmap_target : Node :
	set = clipmap_set_target
@export var _clipmap_tile_resolution := 60
#@export var _clipmap_height_map : Texture2D
@export var _clipmap_height_scale : float = 1.0 : 
	set(x): _clipmap_height_scale = x; clipmap_update_shader()
@export var _clipmap_height_offset : float = 0.0 :
	set(x): _clipmap_height_offset = x; clipmap_update_shader()
@export_range(1, 10, 1, "or_greater") var _clipmap_levels_count : int = 5
@export var _clipmap_collider_enable : bool = false
@export var _clipmap_collider_size : float = 32.0
@export var _clipmap_collider_resolution : int = 64
@export var _clipmap_collider_chunk_count : int = 9
@export var _clipmap_target_position : Vector3
@export var _clipmap_reinitialize : bool = false :
	set(_x): _clipmap_reinitialize = false; clipmap_reinitialize()
@export var _clipmap_vizualize_parts : bool = false : 
	set(x): _clipmap_vizualize_parts = x; clipmap_update_shader()
@export var _clipmap_shader_material : ShaderMaterial = ShaderMaterial.new()

var _clipmap_levels : Array[Node3D] = []
var _clipmap_collider_chunks : Array[CollisionShape3D] = []
var _clipmap_collider_staticbody : StaticBody3D
var _clipmap_collider_height_image : Image
#var _clipmap_collider_holes_image : Image #//-TODO Add support for holes in Terrain with image masking!
var _clipmap_collider_uv_scale : float 
var _clipmap_target_last_pos : Vector3
var _clipmap_editor_updates_enable : bool = true

func clipmap_set_target(x):
	print("Settin' Target: ",x)
	_clipmap_target = x
	
func clipmap_update_target_position(target_pos : Vector3):
	_clipmap_target_last_pos = target_pos
	_clipmap_target_position = _clipmap_target_last_pos
	_clipmap_shader_material.set_shader_parameter("target_position",_clipmap_target_position)

func clipmap_update_shader():
	_clipmap_shader_material.set_shader_parameter("height_scale",_clipmap_height_scale)
	_clipmap_shader_material.set_shader_parameter("height_offset",_clipmap_height_offset)
	_clipmap_shader_material.set_shader_parameter("target_position",_clipmap_target_position)
	_clipmap_shader_material.set_shader_parameter("_debug_shader_enable",_clipmap_vizualize_parts)
#	#//- DETOX shader
#	_clipmap_shader_material.set_shader_parameter("height_map",_terrain_HeightMap)
#	_clipmap_shader_material.set_shader_parameter("height_scale",_terrain_HeightScale)

func clipmap_update_position(level : int, target_position : Vector3):
	#//-Now we gotta update the ClipMap based on the target movement, SNAP and MOVE those quad-meshes
	if level >= _clipmap_levels.size():
		print("[CLIPMAP] ERROR: Attempted to update nonexistant ClipMap Level")
		return false
	#var node_scale : Vector3 = _clipmap_levels[level].get_scale()

	var level_incr : float = scale.x * pow(2,level)
	var level_pos : Vector3 = _clipmap_levels[level].get_position()

	#var diffVec : Vector3 = (target_position - level_pos)
	if level_pos.distance_to(target_position) < 0.001:
		return

	var newX := level_pos.x
	var newZ := level_pos.z
	
	newX = snapped(target_position.x, level_incr)
	newZ = snapped(target_position.z, level_incr)

	var new_pos : Vector3 = Vector3(newX,0,newZ)
	_clipmap_levels[level].set_position(new_pos)

	var dist_snapped := (new_pos-level_pos) / level_incr
	if dist_snapped != Vector3.ZERO:
		var mesh_gapper_x := _clipmap_levels[level].get_node("MeshGapper_X")
		var mesh_gapper_z := _clipmap_levels[level].get_node("MeshGapper_Z")

		if level < _clipmap_levels.size()-1:
			#var next_level_pos : Vector3 = _clipmap_levels[level+1].get_position()
			#var next_level_incr : float = scale.x * pow(2,level+1)
			#var diff_vec : Vector3 = (next_pos - level_pos)
			#var diff_vec : Vector3 = (next_level_pos - new_pos)
			#var diff_sign : Vector3 = diff_vec.sign()

			var level_scale = pow(2, level)
			var gapper_x_pos := Vector3((_clipmap_tile_resolution*level_scale*2)+level_scale, 0, 0)
			var gapper_z_pos := Vector3(0, 0, (_clipmap_tile_resolution*level_scale*2)+level_scale)
			if int(new_pos.z / level_scale) % 2 != 0:
				gapper_z_pos.z *= -1;
			if int(new_pos.x / level_scale) % 2 != 0:
				gapper_x_pos.x *= -1;
				gapper_z_pos.x = -level_incr;
			mesh_gapper_x.set_position(gapper_x_pos)
			mesh_gapper_z.set_position(gapper_z_pos)

			if abs(target_position.x - level_pos.x)+(level_incr*0.5) >= level_incr or abs(target_position.z - level_pos.z)+(level_incr*0.5) >= level_incr:
				#print("[CLIPMAP] Moving Next Level ", level+1)
				clipmap_update_position(level+1, target_position + Vector3((level_incr*-0.5),0,(level_incr*-0.5)))

func clipmap_initialize():
	var time_start := Time.get_ticks_msec()
	print("[CLIPMAP] ", get_name(), " Initialization")
	var str_collider := ""
	_clipmap_levels.clear()
	for level in range(_clipmap_levels_count):
		_clipmap_levels.push_back(clipmap_generate_level(level))
	if _clipmap_collider_enable:
		_clipmap_collider_staticbody = clipmap_generate_collider()
		#clipmap_update_collider(_clipmap_target.get_position()*Vector3(1,0,1))
		str_collider = " and Collider"
	print("[CLIPMAP] ", get_name(), " Layers (", _clipmap_levels_count, ")", str_collider," generated in ", Time.get_ticks_msec() - time_start, "ms")

func clipmap_reinitialize():
	#//- Clean out the Clipmap node contents
	for child in get_children():
		child.queue_free()
	#//- Reset the last target position (to force update_position when initialized)
	_clipmap_target_last_pos = Vector3.ZERO
	#call_deferred( "clipmap_initialize")
	#//- Initialize clipmap again
	clipmap_initialize()

func clipmap_world_to_height_map_uv(pos : Vector3):
	#//-SHADER CODE FOR UV COORDS
	#ivec2 diffuse_map_size = textureSize(diffuse_map, 0);
	#vec2 pointXY_diffuse = vertex_position.xz * 1.0/vec2(diffuse_map_size) * uv_scale;
	var height_map_image : Image = _clipmap_shader_material.get_shader_parameter("height_map").get_image()
	var height_map_uv_scale : float = _clipmap_shader_material.get_shader_parameter("uv_scale")
	#var height_map_uv_scale : float = _clipmap_shader_material.get_shader_parameter("uv_scale")
	if not height_map_image:
		return Vector2.ZERO
	var height_map_size := Vector2(height_map_image.get_width(), height_map_image.get_height())
	#print(pos, " | ", fmod_alt(pos.x, height_map_size.x), ", ", fmod_alt(pos.z, height_map_size.y))
	var pos_uv := (Vector2(fposmod(pos.x * height_map_uv_scale, height_map_size.x), fposmod(-pos.z * height_map_uv_scale, height_map_size.y)) / height_map_size)
	return pos_uv

func clipmap_generate_collider():
	#//- TODO: This fails to get_image() when the HeightMap is a NoiseTexture
	_clipmap_collider_height_image = _clipmap_shader_material.get_shader_parameter("height_map").get_image()
	_clipmap_collider_uv_scale = _clipmap_shader_material.get_shader_parameter("uv_scale")
	if not _clipmap_collider_height_image:
		print("[CLIPMAP] ", get_name(), " Failed to generate Collider, missing Height Map")
		_clipmap_collider_enable = false
		return
	var static_body := StaticBody3D.new()
	static_body.set_name("ClipMapStaticBody")
	add_child(static_body)

	_clipmap_collider_chunks.clear()
	for chunk in range(_clipmap_collider_chunk_count):
		var height_map_shape := HeightMapShape3D.new()
		var collider := CollisionShape3D.new()
		collider.set_name("ClipMapCollider_"+str(chunk))
		collider.set_shape(height_map_shape)
		var offset := Vector3(chunk * _clipmap_collider_size, 0, 0)
		collider.set_position(offset)
		static_body.add_child(collider)
		_clipmap_collider_chunks.push_back(collider)
	return static_body

func clipmap_update_collider(chunk : int, target_position : Vector3):
	if chunk >= _clipmap_collider_chunks.size():
		print("[CLIPMAP] ERROR: Attempted to update nonexistant ClipMap Collider Chunk")
		return false

	var clipmap_collider = _clipmap_collider_chunks[chunk]
	var height_map_shape : HeightMapShape3D = clipmap_collider.get_shape()

	var newX = snapped(target_position.x, _clipmap_collider_size / _clipmap_collider_resolution)
	var newZ = snapped(target_position.z, _clipmap_collider_size / _clipmap_collider_resolution)

	var clipmap_staticbody_pos : Vector3 = _clipmap_collider_staticbody.get_position()
	var clipmap_collider_offset : Vector3 = _clipmap_collider_chunks[chunk].get_position()
	var clipmap_collider_pos = clipmap_staticbody_pos + clipmap_collider_offset
	var clipmap_target_pos := Vector3(newX, target_position.y, newZ)

	if abs(clipmap_collider_pos.x - target_position.x) < _clipmap_collider_size * 0.5 and abs(clipmap_collider_pos.z - target_position.z) < _clipmap_collider_size * 0.5:
		return

	var collider_scale := _clipmap_collider_size / float(_clipmap_collider_resolution)
	_clipmap_collider_staticbody.set_position(clipmap_target_pos - Vector3(collider_scale, 0, collider_scale) * 0.5) #//- Gotta offset the collision mesh by a bit to get it all to line up properly
	_clipmap_collider_staticbody.set_scale(Vector3(collider_scale, 1.0, collider_scale))

	var height_map_array : Array[float] = clipmap_sample_height_map(clipmap_target_pos, _clipmap_collider_size, _clipmap_collider_resolution)
	height_map_shape.set_map_width(_clipmap_collider_resolution)
	height_map_shape.set_map_depth(_clipmap_collider_resolution)
	height_map_shape.set_map_data(height_map_array)
	#height_map_shape.set_scale(Vector3(collider_scale, 1.0, collider_scale))

func clipmap_sample_height_map(pos : Vector3, sample_size : float, num_points : float):
	var time_start := Time.get_ticks_msec()
	#print("[CLIPMAP] ", get_name(), " HeightMap Sampling")
	var height_map_uv_scale : float = _clipmap_shader_material.get_shader_parameter("uv_scale")
	var height_map_size := Vector2(_clipmap_collider_height_image.get_width(), _clipmap_collider_height_image.get_height())

#	pos += Vector3(size / num_points, 0, size / num_points) * 0.5

	var height_map_center_pos_uv : Vector2 = (Vector2(fposmod(pos.x * height_map_uv_scale, height_map_size.x), fposmod(-pos.z * height_map_uv_scale, height_map_size.y)) / height_map_size)
	var height_map_center_pos_pixel := height_map_center_pos_uv * height_map_size

	var time_check1 := Time.get_ticks_msec()

	var height_map_sample_incr := (height_map_uv_scale * sample_size) / num_points
	#var height_map_world_incr := Vector2(sample_size, sample_size) / num_points
	var height_map_array : Array[float] = []
	var count := 0
	for y in range(-num_points*0.5, num_points*0.5):
		for x in range(-num_points*0.5, num_points*0.5):
			#var debug_size = 0.5
			#var offset_world := Vector2(x, -y) * height_map_world_incr
			var offset_pixel := Vector2(x, -y) * height_map_sample_incr
			var height_map_pixel := Vector2(fposmod(height_map_center_pos_pixel.x + offset_pixel.x, height_map_size.x), fposmod(height_map_center_pos_pixel.y + offset_pixel.y, height_map_size.y))
			var height_map_value : float = _clipmap_collider_height_image.get_pixelv(height_map_pixel).r
			#var debug_pos := Vector3(pos.x + offset_world.x, height_map_value * _clipmap_height_scale - _clipmap_height_offset, pos.z - offset_world.y)
			#var debug_color : Color = lerp(Color.GREEN, Color.RED, height_map_value*3)
			#DebugTools.draw_cube(debug_pos, Vector3.ZERO, 0.5, debug_color, 5.0, count/(num_points*num_points))
			#clipmap_spawn_debugbox(debug_pos, 0.5, debug_color, 5.0, count/(num_points*num_points))
			#//- Punch a hole at 0,0 for testing
#			if y == 0 and x == 0:
#				height_map_array.push_back(-INF)
#			else:
#				height_map_array.push_back(height_map_value * _clipmap_height_scale - _clipmap_height_offset)
#			var rounding : float = 1.00
#			height_map_array.push_back(float(int((height_map_value * _clipmap_height_scale - _clipmap_height_offset)*rounding)) / rounding)
			height_map_array.push_back(height_map_value * _clipmap_height_scale - _clipmap_height_offset)
			count += 1
	var time_end := Time.get_ticks_msec()
	print("[CLIPMAP] ", get_name(), " HeightMap Sampled with ", count," points in ", time_end - time_start, "ms, (", time_check1 - time_start, "ms, ", time_end - time_check1, "ms)")
	return height_map_array

func clipmap_generate_level(level : int):
	print("[CLIPMAP] ", get_name(), " Generating Mesh Layer ", str(level))
	var time_start := Time.get_ticks_msec()
	var level_scale := pow(2, level)
	#var scale_vec := Vector3(level_scale, 1, level_scale)
	var shader_mat := _clipmap_shader_material

	#//- First, create a LOD level container node
	var level_node := Node3D.new()
	level_node.set_name("ClipMapLevel"+str(level))
	add_child(level_node)
	#//- Next, if LOD0, build out cross mesh for center
	var mesh : MeshInstance3D
	if level == 0:
		mesh = clipmap_generate_mesh("mesh_cross", "MeshCross", Vector3.ZERO, level_scale, shader_mat)
		level_node.add_child(mesh)

	#//- Next, build out grid of Tile planes
	for x in range(4):
		for z in range(4): 
			#//- draw a 4x4 set of tiles. cut out the middle 2x2 unless we're at the finest level
			if(level != 0 && ( x == 1 || x == 2 ) && ( z == 1 || z == 2 )):
				continue;
			var gap_offset := Vector2((1 if x >= 2 else 0), (1 if z >= 2 else 0)) * level_scale;
			var new_xz := Vector2((x-2)*_clipmap_tile_resolution*level_scale + gap_offset.x, (z-2)*_clipmap_tile_resolution*level_scale + gap_offset.y)
			mesh = clipmap_generate_mesh("mesh_tile", "MeshTile_"+str(x)+"_"+str(z), Vector3(new_xz.x, 0, new_xz.y), level_scale, shader_mat)
			level_node.add_child(mesh)

	#//- Build out X-axis gapper piece that make up half of the L
	mesh = clipmap_generate_mesh("mesh_gapper_x", "MeshGapper_X", Vector3((_clipmap_tile_resolution*level_scale*2)+level_scale, 0, 0), level_scale, shader_mat)
	level_node.add_child(mesh)

	#//- Build out Z-axis gapper piece that make up half of the L
	mesh = clipmap_generate_mesh("mesh_gapper_z", "MeshGapper_Z", Vector3(0, 0, (_clipmap_tile_resolution*level_scale*2)+level_scale), level_scale, shader_mat)
	level_node.add_child(mesh)

	#//- Build out 4 filler meshes
	mesh = clipmap_generate_mesh("mesh_filler_x", "MeshFiller_X_1", Vector3(0, 0, (_clipmap_tile_resolution*1.5*level_scale) + level_scale), level_scale, shader_mat)
	level_node.add_child(mesh)

	mesh = clipmap_generate_mesh("mesh_filler_x", "MeshFiller_X_2", Vector3(0, 0, -(_clipmap_tile_resolution*1.5*level_scale)), level_scale, shader_mat)
	level_node.add_child(mesh)

	mesh = clipmap_generate_mesh("mesh_filler_z", "MeshFiller_Z_1", Vector3((_clipmap_tile_resolution*1.5*level_scale) + level_scale, 0, 0), level_scale, shader_mat)
	level_node.add_child(mesh)

	mesh = clipmap_generate_mesh("mesh_filler_z", "MeshFiller_Z_2", Vector3(-(_clipmap_tile_resolution*1.5*level_scale), 0, 0), level_scale, shader_mat)
	level_node.add_child(mesh)

	#//- Finally build out the Seam mesh to help fill in the gaps where LODs transition, skip the last LOD
	if level > 0 && level < _clipmap_levels_count:
		mesh = clipmap_generate_mesh("mesh_seam", "MeshSeam", Vector3.ZERO, pow(2, level-1), shader_mat)
		level_node.add_child(mesh)
	
	print("[CLIPMAP] ", get_name(), " Mesh Layer ", level, " generated in ", Time.get_ticks_msec() - time_start, "ms")
	return level_node

func clipmap_generate_mesh(mesh_mesh : String, mesh_name : String, mesh_pos : Vector3, mesh_scale : float, mesh_shader_mat : ShaderMaterial, mesh_color : Color = Color.TRANSPARENT):
	var mesh_node := MeshInstance3D.new()
	match mesh_mesh:
		"mesh_cross":
			if(mesh_color == Color.TRANSPARENT):
				mesh_node.mesh = clipmap_generate_mesh_cross()
			else:
				mesh_node.mesh = clipmap_generate_mesh_cross(mesh_color)
		"mesh_tile":
			if(mesh_color == Color.TRANSPARENT):
				mesh_node.mesh = clipmap_generate_mesh_tile()
			else:
				mesh_node.mesh = clipmap_generate_mesh_tile(mesh_color)
		"mesh_gapper_x":
			if(mesh_color == Color.TRANSPARENT):
				mesh_node.mesh = clipmap_generate_mesh_gapper_x()
			else:
				mesh_node.mesh = clipmap_generate_mesh_gapper_x(mesh_color)
		"mesh_gapper_z":
			if(mesh_color == Color.TRANSPARENT):
				mesh_node.mesh = clipmap_generate_mesh_gapper_z()
			else:
				mesh_node.mesh = clipmap_generate_mesh_gapper_z(mesh_color)
		"mesh_filler_x":
			if(mesh_color == Color.TRANSPARENT):
				mesh_node.mesh = clipmap_generate_mesh_filler_x()
			else:
				mesh_node.mesh = clipmap_generate_mesh_filler_x(mesh_color)
		"mesh_filler_z":
			if(mesh_color == Color.TRANSPARENT):
				mesh_node.mesh = clipmap_generate_mesh_filler_z()
			else:
				mesh_node.mesh = clipmap_generate_mesh_filler_z(mesh_color)
		"mesh_seam":
			if(mesh_color == Color.TRANSPARENT):
				mesh_node.mesh = clipmap_generate_mesh_seam()
			else:
				mesh_node.mesh = clipmap_generate_mesh_seam(mesh_color)
		_:
			return

	mesh_node.mesh.set_custom_aabb(mesh_node.mesh.get_aabb().expand(Vector3(0.0,-_clipmap_height_scale,0.0)).expand(Vector3(0.0,_clipmap_height_scale,0.0)))
	mesh_node.set_name(mesh_name)
	mesh_node.set_scale(Vector3(mesh_scale, 1, mesh_scale))
	mesh_node.set_position(mesh_pos)
	mesh_node.set_surface_override_material(0, mesh_shader_mat)
	return mesh_node

func clipmap_generate_mesh_tile(vertex_color : Color = Color.WHITE):
	var st = SurfaceTool.new();
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(vertex_color)
	for z in range(_clipmap_tile_resolution + 1):
		for x in range(_clipmap_tile_resolution + 1):
			st.add_vertex(Vector3(x, 0, z));
	for z in range(_clipmap_tile_resolution):
		for x in range(_clipmap_tile_resolution):
			st.add_index(z * (_clipmap_tile_resolution + 1) + x );
			st.add_index((z + 1) * (_clipmap_tile_resolution + 1) + x + 1);
			st.add_index((z + 1) * (_clipmap_tile_resolution + 1) + x);

			st.add_index(z * (_clipmap_tile_resolution + 1) + x);
			st.add_index(z * (_clipmap_tile_resolution + 1) + x + 1);
			st.add_index((z + 1) * (_clipmap_tile_resolution + 1) + x + 1);
	return st.commit();

func clipmap_generate_mesh_filler_x(vertex_color : Color = Color.BLUE):
	var st = SurfaceTool.new();
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(vertex_color)

	for i in range(_clipmap_tile_resolution+1):
		st.add_vertex(Vector3(0, 0, i - _clipmap_tile_resolution*0.5))
		st.add_vertex(Vector3(1, 0, i - _clipmap_tile_resolution*0.5))

	for i in range(_clipmap_tile_resolution):
		st.add_index(i*2+1)
		st.add_index(i*2+3)
		st.add_index(i*2)
		
		st.add_index(i*2+3)
		st.add_index(i*2+2)
		st.add_index(i*2)

	return st.commit()

func clipmap_generate_mesh_filler_z(vertex_color : Color = Color.RED):
	var st = SurfaceTool.new();
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(vertex_color)

	for i in range(_clipmap_tile_resolution+1):
#		st.add_vertex(Vector3(0, 0, i - _clipmap_tile_resolution*0.5))
#		st.add_vertex(Vector3(1, 0, i - _clipmap_tile_resolution*0.5))
		st.add_vertex(Vector3(i - _clipmap_tile_resolution*0.5, 0, 0))
		st.add_vertex(Vector3(i - _clipmap_tile_resolution*0.5, 0, 1))

	for i in range(_clipmap_tile_resolution):
		st.add_index(i*2)
		st.add_index(i*2+3)
		st.add_index(i*2+1)
		
		st.add_index(i*2)
		st.add_index(i*2+2)
		st.add_index(i*2+3)

	return st.commit()

func clipmap_generate_mesh_gapper_x(vertex_color : Color = Color.GREEN):
	var st = SurfaceTool.new();
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(vertex_color)

	for i in range(_clipmap_tile_resolution*4+2):
		st.add_vertex(Vector3(0, 0, i - (_clipmap_tile_resolution+1)*2 + 2))
		st.add_vertex(Vector3(1, 0, i - (_clipmap_tile_resolution+1)*2 + 2))

	for i in range(_clipmap_tile_resolution*4+1):
		st.add_index(i*2+1)
		st.add_index(i*2+3)
		st.add_index(i*2)
		
		st.add_index(i*2+3)
		st.add_index(i*2+2)
		st.add_index(i*2)

	return st.commit()

func clipmap_generate_mesh_gapper_z(vertex_color : Color = Color.DARK_GREEN):
	var st = SurfaceTool.new();
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(vertex_color)

	for i in range(_clipmap_tile_resolution*4+3):
		st.add_vertex(Vector3(i - (_clipmap_tile_resolution+1)*2 + 2, 0, 0))
		st.add_vertex(Vector3(i - (_clipmap_tile_resolution+1)*2 + 2, 0, 1))

	for i in range(_clipmap_tile_resolution*4+2):
		st.add_index(i*2)
		st.add_index(i*2+3)
		st.add_index(i*2+1)
		
		st.add_index(i*2)
		st.add_index(i*2+2)
		st.add_index(i*2+3)

	return st.commit()

func clipmap_generate_mesh_cross(vertex_color : Color = Color.PURPLE):
	var st = SurfaceTool.new();
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(vertex_color)

	for i in range(_clipmap_tile_resolution*2+2):
		st.add_vertex(Vector3(0, 0, i - _clipmap_tile_resolution))
		st.add_vertex(Vector3(1, 0, i - _clipmap_tile_resolution))
#		st.add_vertex(Vector3(i - _clipmap_tile_resolution*0.5, 0, 0))
#		st.add_vertex(Vector3(i - _clipmap_tile_resolution*0.5, 0, 1))

	var count := 0
	for i in range(_clipmap_tile_resolution*2+1):
		st.add_index(i*2+1)
		st.add_index(i*2+3)
		st.add_index(i*2)
		
		st.add_index(i*2+3)
		st.add_index(i*2+2)
		st.add_index(i*2)
		count += 1

	for i in range(_clipmap_tile_resolution*2+2):
		st.add_vertex(Vector3(i - _clipmap_tile_resolution, 0, 0))
		st.add_vertex(Vector3(i - _clipmap_tile_resolution, 0, 1))
	
	for i in range(_clipmap_tile_resolution*2+1):
		var start := count + 1
		if i != _clipmap_tile_resolution:
			st.add_index((i+start)*2)
			st.add_index((i+start)*2+3)
			st.add_index((i+start)*2+1)
			
			st.add_index((i+start)*2)
			st.add_index((i+start)*2+2)
			st.add_index((i+start)*2+3)

	return st.commit()

func clipmap_generate_mesh_seam(vertex_color : Color = Color.MAGENTA):
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(vertex_color)

	var vertices: Array[Vector3] = []
	var clipmap_vert_resolution = (((_clipmap_tile_resolution * 4) + 1) + 1)
	vertices.resize(clipmap_vert_resolution * 4)
	for i in range(clipmap_vert_resolution):
		vertices[clipmap_vert_resolution * 0 + i] = Vector3(i, 0, 0);
		vertices[clipmap_vert_resolution * 1 + i] = Vector3(clipmap_vert_resolution, 0, i);
		vertices[clipmap_vert_resolution * 2 + i] = Vector3(clipmap_vert_resolution - i, 0, clipmap_vert_resolution);
		vertices[clipmap_vert_resolution * 3 + i] = Vector3(0, 0, clipmap_vert_resolution - i);

	for i in range(vertices.size()):
		#if i % 2 == 0:
		#	vertices[i] += Vector3(0,5,0)
		st.add_vertex(vertices[i] + Vector3(-clipmap_vert_resolution*0.5+1,0,-clipmap_vert_resolution*0.5+1))

	var indices: Array[int] = []
	indices.resize(clipmap_vert_resolution * 6);
	var n := 0
	for i in range(0, clipmap_vert_resolution * 4, 2):
		indices[n] = i + 1; n+=1
		indices[n] = i; n+=1
		indices[n] = i + 2; n+=1
	indices[n-1] = 0
	for i in range(indices.size()):
		st.add_index(indices[i])
	return st.commit()

func clipmap_get_target_position():
	var target_pos := Vector3.ZERO
	if _clipmap_editor_updates_enable:
		target_pos = %Player.get_position()
	elif _clipmap_target:
		target_pos = _clipmap_target.get_position() / get_scale()
	return target_pos

# Called when the node enters the scene tree for the first time.
func _ready():
	clipmap_initialize()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	var target_pos : Vector3 = clipmap_get_target_position()
	target_pos *= Vector3(1, 0, 1)
	if _clipmap_collider_enable:
		clipmap_update_collider(0, target_pos) #//- TODO, come fix this
	if target_pos != Vector3.ZERO and Vector3(_clipmap_target_last_pos.x, 0, _clipmap_target_last_pos.z).distance_to(target_pos) > (1.0 / get_scale().x):
		clipmap_update_position(0, target_pos)
		clipmap_update_target_position(target_pos)
