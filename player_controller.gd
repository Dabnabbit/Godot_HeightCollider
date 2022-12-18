@tool
extends RigidBody3D
class_name PlayerController

#//-TEST CONTROLS
#var gravity : float = ProjectSettings.get_setting("physics/3d/default_gravity")
var gravity : float = ProjectSettings.get_setting("physics/3d/default_gravity")
var velocity := Vector3.ZERO
var mouse_sensitivity := 0.01
var _input_direction := Vector2.ZERO
var _mouse_delta := Vector2.ZERO
var _mouse_last_enable := Time.get_ticks_msec()
var _mouse_is_clicking_left : bool = false
var _mouse_is_clicking_mid : bool = false
var _mouse_is_clicking_right : bool = false
var _mouse_last_click_left : float = 0.0
var _mouse_last_click_right : float = 0.0
var _mouse_click_delay : float = 0.1

@export_category("Player")
@export var player_mass : float = 50.0
@export_category("Movement")
@export var move_relative_to_camera : bool = true
@export var move_speed_max := 10.0
@export var move_stance_spread := 0.25
@export var move_accel := 25.0
#@export_exp_easing("attenuation") var move_accel_dot := 1.0 #// This doesn't QUITE work for what we need...
@export var move_accel_dot := Curve.new() #// Should go from xy(-1,2) to (0,1) to (1,1) OR xy(0,2) to (0.5,1) to (1,1)
@export var move_accel_max_force := 150.0
@export var move_accel_max_force_dot := Curve.new() #// Should go from xy(-1,2) to (0,1) to (1,1)
@export var move_angle_multiplier : float = 1.0
@export var move_angle_dot := Curve.new() #// Should go from xy(-1,2) to (0,1) to (1,1)

@export var move_snap_length : float = 0.4
@export_category("Jumping")
@export var move_jump_height : float = 2.0
@export var move_jump_coyote_time : float = 0.2
@export var move_jump_delay : float = 0.5
@export var move_terminal_velocity : float = 100.0
@export var move_enable_jetpack : bool = false
@export var move_jetpack_force : float = 200.0
@export_category("Height Spring")
@export var hover_ray_len : float = 3.0
@export var hover_ray_vector := Vector3(0.0, -1.0, 0.0)
@export var hover_ray_predictive : bool = true
@export var hover_spring_height : float = 1.5
@export var hover_spring_str : float = 3000.0
@export var hover_spring_damper : float = 50.0
@export_category("Upright Spring")
@export var upright_spring_str : float = 3000.0
@export var upright_spring_damper : float = 100.0
#@export_range(0.0, 1.0, 0.05) var move_lean_force : float = 0.5
@export var move_lean_force : float = 0.5

var _mesh : MeshInstance3D
var _mesh_leg_l : Node3D
var _mesh_leg_r : Node3D
var _axis_lock : Node3D
var _camera_pivot : Node3D
var _camera : Camera3D
var _ray_node_l : RayCast3D
var _ray_node_r : RayCast3D

var _hover_ray_last_dist : float
var _move_target_velocity : Vector3
var _move_target_rotation : Vector3 #//-TODO: Implement better interpolated rotation
var _move_leg_l_position : Vector3
var _move_leg_r_position : Vector3
var _move_landing_recovery_time : float = 0.0
var _move_disable_timer : float = 0.0
var _time_on_floor : float = 0.0
var _last_on_floor : float = 0.0
var _last_jump : float = 0.0
var _is_pressing_jump : bool
var _is_on_floor : bool
var _is_jumping : bool
var _is_jetting : bool 

	#//- Impulse = mass * velocity
	#//- Force = mass * (velocity * delta)
	#//- Accel = (velocity * delta)
	#//- Accel = force / mass

func player_is_pressing_jump():
	return _is_pressing_jump

func player_is_jumping():
	return _is_jumping

func player_is_able_to_jump():
	if _last_on_floor < move_jump_coyote_time and _last_jump <= 0.0 and _move_disable_timer <= 0.0 and _time_on_floor > 0.35 and _move_landing_recovery_time <= 0.0 and player_is_on_floor():
		return true
	else:
		return false

func player_is_on_floor():
	var snap : float = move_snap_length
	if _is_jumping and velocity.y > 0: #//- If currenting on the upward motion of a jump, should NOT be on floor
		#print("probably should say not on floor here...")
		return false
	if _is_jumping or _is_jetting:# or _time_on_floor < 0.2:
		snap = 0.0
	var collision_distance : float = player_get_collision_distance()
	#if collision_distance - _hover_ray_last_dist > 0.2:
	if collision_distance - _hover_ray_last_dist > move_snap_length*0.5:
		DebugTools.draw_cube(position-Vector3(0,hover_spring_height,0), rotation, 0.5, Color.RED, 10.0)
		#print("Ramp!")
		snap = 0.0
	_hover_ray_last_dist = collision_distance
	if collision_distance <= hover_spring_height + snap: #_hover_ray_last_dist
		return true
	else:
		return false

func player_get_is_on_floor():
	return _is_on_floor

func player_get_last_on_floor():
	return _last_on_floor

func player_get_time_on_floor():
	return _time_on_floor

func player_is_ray_colliding():
	if _ray_node_l.is_colliding() or _ray_node_r.is_colliding():
		return true
	return false

func player_get_collision_distance(y_only : bool = true):
	if y_only:
		var ray_dist_l :float = _ray_node_l.get_global_position().y - _ray_node_l.get_collision_point().y
		var ray_dist_r : float = _ray_node_r.get_global_position().y - _ray_node_r.get_collision_point().y
		return (ray_dist_l+ray_dist_r)*0.5
	else:
		var ray_dist_l : float = _ray_node_l.get_global_position().distance_to(_ray_node_l.get_collision_point())
		var ray_dist_r : float = _ray_node_r.get_global_position().distance_to(_ray_node_r.get_collision_point())
		return (ray_dist_l+ray_dist_r)*0.5

func player_get_collision_point(debug : bool = false):
	var collision_point_l : Vector3
	var collision_point_r : Vector3
	if _ray_node_l.is_colliding() and _ray_node_r.is_colliding():
		collision_point_l = _ray_node_l.get_collision_point()
		collision_point_r = _ray_node_r.get_collision_point()
		if debug:
			DebugTools.draw_cube(collision_point_l, Vector3.ZERO, 0.2, Color.SPRING_GREEN)
			DebugTools.draw_cube(collision_point_r, Vector3.ZERO, 0.2, Color.ORANGE_RED)
		return (collision_point_l + collision_point_r)*0.5
	elif _ray_node_l.is_colliding():
		collision_point_l = _ray_node_l.get_collision_point()
		if debug:
			DebugTools.draw_cube(collision_point_l, Vector3.ZERO, 0.2, Color.SPRING_GREEN)
		return collision_point_l
	elif _ray_node_r.is_colliding():
		collision_point_r = _ray_node_r.get_collision_point()
		if debug:
			DebugTools.draw_cube(collision_point_r, Vector3.ZERO, 0.2, Color.ORANGE_RED)
		return collision_point_r
	else:
		return Vector3.ZERO

func player_get_collision_normal():
	#var ray_node : RayCast3D = _ray_node_l
	if _ray_node_l.is_colliding() and _ray_node_r.is_colliding():
		return (_ray_node_l.get_collision_normal() + _ray_node_r.get_collision_normal()).normalized()
	elif _ray_node_l.is_colliding():
		return _ray_node_l.get_collision_normal()
	elif _ray_node_r.is_colliding():
		return _ray_node_r.get_collision_normal()
	else:
		return Vector3.UP

func _player_initialize_ray():
	_ray_node_l = RayCast3D.new()
	_ray_node_r = RayCast3D.new()
	_ray_node_l.set_name("RayCastDown")
	_ray_node_r.set_name("RayCastPredict")
	_ray_node_l.add_exception(self)
	_ray_node_r.add_exception(self)
	_ray_node_l.set_exclude_parent_body(true)
	_ray_node_r.set_exclude_parent_body(true)
	_ray_node_l.set_collide_with_areas(true)
	_ray_node_r.set_collide_with_areas(true)
	_ray_node_l.set_collide_with_bodies(true)
	_ray_node_r.set_collide_with_bodies(true)
	_ray_node_l.set_debug_shape_custom_color(Color.DARK_RED)
	_ray_node_r.set_debug_shape_custom_color(Color.DARK_GREEN)
	_ray_node_l.set_debug_shape_thickness(4)
	_ray_node_r.set_debug_shape_thickness(4)
	_ray_node_l.set_position(Vector3.LEFT*move_stance_spread) #//-This is backwards... I think because of the -Z axis
	_ray_node_r.set_position(Vector3.RIGHT*move_stance_spread)
	_ray_node_l.set_target_position(hover_ray_vector * hover_ray_len)
	_ray_node_r.set_target_position(hover_ray_vector * hover_ray_len)
	_axis_lock.add_child(_ray_node_l)
	_axis_lock.add_child(_ray_node_r)

func _player_update_ray(_delta : float):
	var velocity_input :=  velocity * Vector3(1,0,1)
	velocity_input *= _delta
	#var ray_target : Vector3 = hover_ray_vector * hover_ray_len
	var ray_target_l : Vector3 = ((hover_ray_vector * hover_spring_height) + velocity_input).normalized()
	var ray_target_r : Vector3 = ((hover_ray_vector * hover_spring_height) + velocity_input).normalized()
	#DebugTools.draw_cube(position + ray_target_new * hover_spring_height, rotation, 0.2, Color.GREEN_YELLOW)
	_ray_node_l.set_target_position(ray_target_l * hover_ray_len)
	_ray_node_r.set_target_position(ray_target_r * hover_ray_len)

func _player_update_legs(_delta, debug : bool = false):
	if _is_jumping or _is_jetting:
		return
	var collision_point_l : Vector3 = _move_leg_l_position
	var collision_point_r : Vector3 = _move_leg_l_position
	if _ray_node_l.is_colliding() and _ray_node_r.is_colliding():
		collision_point_l = _ray_node_l.get_collision_point()
		collision_point_r = _ray_node_r.get_collision_point()
	elif _ray_node_l.is_colliding():
		collision_point_l = _ray_node_l.get_collision_point()
	elif _ray_node_r.is_colliding():
		collision_point_r = _ray_node_r.get_collision_point()
	else:
		return
	var dist_l : float = _move_leg_l_position.distance_to(collision_point_l)
	var dist_r : float = _move_leg_r_position.distance_to(collision_point_r)
	#print(dist_l, " | ", dist_r, " ||| ", _move_leg_l_position, " | ", _move_leg_r_position)
	if dist_l > 1.0:
		_move_leg_l_position = collision_point_l
	if dist_r > 1.0:
		_move_leg_r_position = collision_point_r
	#_mesh_leg_l.set_global_position(_move_leg_l_position)
	_mesh_leg_r.set_global_position(_move_leg_r_position)
	_mesh_leg_l.look_at_from_position(_move_leg_l_position, get_global_position() + Vector3.LEFT.rotated(Vector3.UP, _move_target_rotation.y)*move_stance_spread, Vector3.UP)
	_mesh_leg_r.look_at_from_position(_move_leg_r_position, get_global_position() + Vector3.RIGHT.rotated(Vector3.UP, _move_target_rotation.y)*move_stance_spread, Vector3.UP)

func _player_rotate(_delta):
	if _move_target_velocity.length() > 0.1:
		var current_rotation : Vector3 = _mesh.get_rotation()
		#var goal_rotation := Vector3(0.0, atan2(-_move_target_velocity.x, -_move_target_velocity.z), 0.0)
		#_move_target_rotation = current_rotation.slerp(goal_rotation, 0.5)
		_move_target_rotation = Vector3(0.0,lerp_angle(current_rotation.y, atan2(-_move_target_velocity.x, -_move_target_velocity.z), 0.5), 0.0)
		_mesh.set_rotation(_move_target_rotation)
		_ray_node_l.set_position((Vector3.LEFT*move_stance_spread).rotated(Vector3.UP, _move_target_rotation.y))
		_ray_node_r.set_position((Vector3.RIGHT*move_stance_spread).rotated(Vector3.UP, _move_target_rotation.y))

func _player_upright(_delta):
	_axis_lock.set_global_rotation(Vector3.ZERO)
	#var rot : Vector3 = get_rotation()
	var goal := Quaternion.IDENTITY
	var quat_rot : Quaternion = get_quaternion()
	var to_goal : Quaternion = quaternion_shortest_rotation(goal, quat_rot)
	var quat_angle : float = to_goal.get_angle()
	var quat_axis : Vector3 = to_goal.get_axis().normalized()
	apply_torque((quat_axis * (quat_angle * upright_spring_str)) - get_angular_velocity() * upright_spring_damper)

func _player_hover(_delta):
	var collision_distance : float = player_get_collision_distance()
	var ray_node : RayCast3D = _ray_node_l
	ray_node = _ray_node_r
	var ray_dist_l : float = _ray_node_l.get_global_position().y - _ray_node_l.get_collision_point().y
	var ray_dist_r : float = _ray_node_r.get_global_position().y - _ray_node_r.get_collision_point().y
	if ray_node.is_colliding() and player_is_on_floor():
		var snap_force : float = 0.0
		if collision_distance > hover_spring_height:
			snap_force = ray_dist_r - ray_dist_l
			#print(Time.get_ticks_msec(), ": Snappin' : ", collision_distance - hover_spring_height, " | ", dist2-dist1)
		var collision_body : Node3D = ray_node.get_collider()
		#var collision_point : Vector3 = ray_node.get_collision_point()
		var collision_point : Vector3 =  player_get_collision_point(true)
		#var collision_normal : Vector3 = ray_node.get_collision_normal()
		var collision_normal : Vector3 = player_get_collision_normal()
		
		var collision_impact : float = -velocity.dot(collision_normal)
		#var ray_dir : Vector3 = _ray_node.get_target_position()
		var ray_dir : Vector3 = hover_ray_vector*hover_ray_len
		var collision_velocity := Vector3.ZERO #//TODO: get velocity of collided object regardless of object type
		var ray_dir_vel = ray_dir.dot(velocity)
		var collision_dir_vel = ray_dir.dot(collision_velocity)
		var relative_velocity : float = ray_dir_vel - collision_dir_vel
		var float_force : float = collision_distance - hover_spring_height + snap_force
		var spring_force : float = (float_force * hover_spring_str) - (relative_velocity * hover_spring_damper)

		apply_central_force(ray_dir * spring_force)
		if velocity.y < -2.0 and _move_landing_recovery_time <= 0.0:
			_move_landing_recovery_time = absf(collision_impact)*0.2
			print("VelY: ", velocity.y, "; Impact: ", collision_impact, " FloatForce: ", float_force, " | Recovery: ", _move_landing_recovery_time)
		else:
			_move_landing_recovery_time = maxf(0.0, _move_landing_recovery_time-_delta)
#			pass #//- TODO: Reimplement terrain bounce?
#			var bounce : Vector3 = (collision_normal * (collision_impact + 0.001)).normalized()
#			DebugTools.draw_arrow(get_global_position(), collision_point, Color(0.0, 1.0, 0.0, 1.0), 5.0)
#			DebugTools.draw_arrow(get_global_position() - collision_normal, get_global_position(), Color(0.0, 0.0, 1.0, 1.0), 5.0)
#			apply_force(ray_dir * spring_force, -collision_normal)
#		else:
		if collision_body.get_class() == "RigidBody3D":
			collision_body.apply_force(ray_dir * spring_force, collision_point)
	else:
		if player_is_ray_colliding():
			pass
			#print("Collision prep?")

func _player_move(delta):
	var move_speed := move_speed_max
	if _is_jetting:
		move_speed *= 10.0
	#var velocity : Vector3 = get_linear_velocity()
	var move_input := Vector3(_input_direction.x, 0, _input_direction.y)
	if move_relative_to_camera:
		move_input = move_input.rotated(Vector3.UP, _camera_pivot.rotation.y)
	if _move_disable_timer > 0.0:
		move_input = Vector3.ZERO
		_move_disable_timer -= delta
	_move_disable_timer = 0.0
	var lean_force := Vector3.ZERO
	if move_input.length() > 1.0:
		move_input = move_input.normalized()
	if move_input.length() > 0.5:
		lean_force = Vector3(move_input.x, move_lean_force * 2.0, move_input.z)

	var vel_dot : float = move_input.dot(_move_target_velocity.normalized())
	#print(move_input.length(), " , ", vel_dot, " | ",  lean_force)
	var accel_vel_dot : float = move_accel_dot.sample((vel_dot + 1.0)*0.5)
	var accel : float = move_accel * accel_vel_dot
	var goal_vel : Vector3 = move_input * move_speed # * speedFactor?

	#//-TODO: Improve surface normal calculations, perhaps based on surface type, friction, etc? Hard Cap?
	var collision_normal : Vector3 = player_get_collision_normal()
	goal_vel *= (goal_vel.normalized().dot(collision_normal)*move_angle_multiplier+1.0)
	_move_target_velocity = _move_target_velocity.move_toward(goal_vel, accel * delta) 
	var needed_accel : Vector3 = (_move_target_velocity - velocity) / delta
	var accel_max : float = move_accel_max_force * move_accel_max_force_dot.sample((vel_dot + 1.0)*0.5)
	needed_accel = needed_accel.limit_length(accel_max) * Vector3(1,0,1) #//- Cap the accel rate force, and remove any influence on gravity/Y-axis
	apply_force((needed_accel * mass), lean_force)
#	if _move_target_velocity != Vector3.ZERO:
#		#set_rotation(Vector3(0, atan2(-_move_target_velocity.x, -_move_target_velocity.z), 0))
#		_mesh.set_rotation(Vector3(0, atan2(-_move_target_velocity.x, -_move_target_velocity.z), 0))
	#DebugTools.draw_arrow(position + lean_force, position)

func _player_jump(delta):
	if move_enable_jetpack:
		if _is_pressing_jump:
			apply_central_force(Vector3(0, move_jetpack_force, 0))
			_is_jetting = true
		else:
			_is_jetting = false
		return
	if _last_jump > 0.0:
		_last_jump -= delta
		return
	_last_jump = 0.0
	if _is_pressing_jump and player_is_able_to_jump():
		var player_gravity : float = gravity*get_gravity_scale()
		var impulse : float = sqrt(2.0*player_gravity*move_jump_height) * mass
		apply_central_impulse(Vector3(0, impulse, 0))
		_last_jump = move_jump_delay
		_is_jumping = true
		print("Jump!")

func _player_friction(_delta):
	pass

#//- Interestingly enough Godot doesn't seem to have a function to help determine the shortest path of Quaternion direction, just SLERP
func quaternion_shortest_rotation(quat1 : Quaternion, quat2 : Quaternion):
	if quat1.dot(quat2) < 0.0:
		return quat1 * (quat2 * -1.0).inverse()
	else:
		return quat1 * quat2.inverse()

func _player_click_left(_delta):
	DebugTools.spawn_physics_from_mouse("cube", 30.0, 4500.0, 0.1, 5.0, velocity)

func _player_click_right(_delta):
	DebugTools.spawn_physics_from_mouse("sphere", 10.0, 4500.0, 0.1, 2.0, velocity)

func _physics_process(delta):
	velocity = get_linear_velocity()
	_mouse_last_click_left += delta
	_mouse_last_click_right += delta
	if _mouse_is_clicking_left:
		if _mouse_last_click_left > _mouse_click_delay:
			_mouse_last_click_left = 0.0
			_player_click_left(delta)
	if _mouse_is_clicking_right:
		if _mouse_last_click_right > _mouse_click_delay:
			_mouse_last_click_right = 0.0
			_player_click_right(delta)
	#apply_central_force(Vector3(0, -2000.0, 0))
	if Engine.is_editor_hint():
		return
	_player_upright(delta)
	if player_is_ray_colliding():
		#print(player_collision_distance(), " <= ", hover_spring_height)
#		var snap : float = move_snap_length
#		if _is_jumping or _is_jetting:
#			snap = 0.0
#		if player_collision_distance() <= hover_spring_height + snap:
		if player_is_on_floor():
			_is_on_floor = true
			_is_jumping = false
			_time_on_floor += delta
			_last_on_floor = 0.0
		else:
			_is_on_floor = false
			_time_on_floor = 0.0
			_last_on_floor += delta
		_player_hover(delta)
	else:
		_is_on_floor = false
		_time_on_floor = 0.0
		_last_on_floor += delta
	if hover_ray_predictive:
		_player_update_ray(delta)
	_player_jump(delta)
	_player_move(delta)
	_player_rotate(delta)
	_player_update_legs(delta)
	_player_friction(delta)

func _ready():
	print("Initializing Player...")
	set_mass(player_mass)
	set_use_continuous_collision_detection(true)
	#print("Inertia: ", get_inertia())
	#set_inertia(value)
	set_can_sleep(false)
	_mesh = get_node("MeshInstance3D")
	_mesh_leg_l = _mesh.get_node("LegL")
	_mesh_leg_r = _mesh.get_node("LegR")
	_axis_lock = get_node("AxisLock")
	_camera_pivot = _axis_lock.get_node("CameraController")
	_camera = _camera_pivot.get_node("Camera3D")
	_player_initialize_ray()

func _input(event):
	_input_direction = Input.get_vector("run_left", "run_right", "run_forward", "run_back")
	if Input.is_action_pressed("jump"):
		_is_pressing_jump = true
	else:
		_is_pressing_jump = false
	if Input.is_action_pressed("toggle_jetpack"):
		move_enable_jetpack = !move_enable_jetpack
	if Input.is_action_pressed("mouse_capture") and Time.get_ticks_msec() > _mouse_last_enable + 500:
		_mouse_last_enable = Time.get_ticks_msec()
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if event is InputEventMouseButton:
		var mouse_button = event.get_button_index()
		if mouse_button == MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				_mouse_is_clicking_left = true
			else:
				_mouse_is_clicking_left = false
		if mouse_button == MOUSE_BUTTON_MIDDLE:
			if event.is_pressed():
				_mouse_is_clicking_mid = true
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			else:
				_mouse_is_clicking_mid = false
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		if mouse_button == MOUSE_BUTTON_RIGHT:
			if event.is_pressed():
				_mouse_is_clicking_right = true
			else:
				_mouse_is_clicking_right = false
	#if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
	if event is InputEventMouseMotion and _mouse_is_clicking_mid:
		_mouse_delta = event.relative
		_camera_pivot.rotation.x += _mouse_delta.y * -mouse_sensitivity
		_camera_pivot.rotation.y += _mouse_delta.x * -mouse_sensitivity
