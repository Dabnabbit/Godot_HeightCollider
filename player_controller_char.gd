@tool

extends CharacterBody3D

#//-TEST CONTROLS
#var gravity : float = ProjectSettings.get_setting("physics/3d/default_gravity")
var gravity : float = 100.0
var moveSpeed := 50.0
var mouseDelta := Vector2.ZERO
var mouseLastEnable := Time.get_ticks_msec()
var inputDirection := Vector2.ZERO
var heightStop : float = 10.0;
var _ray_node : RayCast3D
var _mesh : MeshInstance3D
var _is_jumping : bool
var _is_on_floor : bool
var _player_float_max = 1.0
var _player_float_current = 1.0

var spring_str : float = 1.0
var spring_damper : float = 1.0

#func ray_down(distance : float):
#	var spaceState := get_world_3d().direct_space_state
#	var exclude : Array[RID] = [self.get_rid()]
#	var rayTest : Dictionary = spaceState.intersect_ray(PhysicsRayQueryParameters3D.create(position+Vector3(0, 0.1, 0), position+Vector3(0, -distance, 0), 255, exclude))
#	return rayTest

func _player_add_force(force : Vector3):
	#//- Impulse = mass * velocity
	#//- Force = mass * (velocity * delta)
	#//- Accel = (velocity * delta)
	#//- Accel = force / mass
	pass

func _player_get_float(delta):
	var collision_point : Vector3 = _ray_node.get_collision_point()
	var collision_normal : Vector3 = _ray_node.get_collision_normal()
	var collision_impact : float = -velocity.dot(collision_normal)
	var collision_distance : float = position.distance_to(collision_point)
	var ray_dir : Vector3 = _ray_node.get_target_position()
	var other_vel := Vector3.ZERO
	var ray_dir_vel = ray_dir.dot(velocity)
	var other_dir_vel = ray_dir.dot(other_vel)
	var rel_vel : float = ray_dir_vel - other_dir_vel

	var x : float = collision_distance - _player_float_max
	var spring_force : float = (x * spring_str) - (rel_vel * spring_damper)

func _physics_process(delta):
	if _ray_node.is_colliding():
		var collision_point : Vector3 = _ray_node.get_collision_point()
		var collision_normal : Vector3 = _ray_node.get_collision_normal()
		var collision_impact := -velocity.dot(collision_normal)
		var ground_dist : float = position.y - collision_point.y
		if velocity.length() > 2.0:
			print(collision_impact)
		
		if ground_dist < _player_float_current:
			if collision_impact > 20.0:
				_player_float_current = 0.25
				_mesh.set_scale(Vector3(1, 0.9, 1))
				_mesh.set_position(Vector3(0, 0.1, 0))
			else:
				_player_float_current = lerp(_player_float_current, _player_float_max, 0.3)
				_mesh.set_scale(lerp(_mesh.get_scale(), Vector3.ONE, 0.3))
				_mesh.set_position(lerp(_mesh.get_position(), Vector3.ZERO, 0.3))
			#print(_ray_node.get_collider().get_name(), "; Dist: ", ground_dist, " | Pos: ", position.y, " | Col:", _player_float_current, " + ", _player_float, " = ", collision_point.y+_player_float_current)
			position.y = max(position.y, collision_point.y + _player_float_current)
			velocity.y = 0.0
			_is_on_floor = true
			DebugTools.draw_arrow(collision_point, collision_point+collision_normal*1.0, Color(0.0, 0.8, 0.8, 1.0), 5.0)
			if collision_impact > 15.0:
				var collision_bounce := collision_normal * (collision_impact*0.25 + 0.001)
				velocity += collision_bounce
				DebugTools.draw_arrow(collision_point-(velocity*delta*4.0), collision_point, Color(0.1, 1.0, 0.0, 1.0), 5.0)
				DebugTools.draw_arrow(collision_point, collision_point+(collision_bounce*delta*4.0), Color(0.0, 1.0, 0.1, 1.0), 5.0)
	else:
		_is_on_floor = false
	if inputDirection != Vector2.ZERO:
		var newDir := Vector3(inputDirection.x, 0, inputDirection.y).rotated(Vector3.UP, $CameraController.rotation.y)
		velocity += newDir * moveSpeed * delta
	elif _is_on_floor:
		velocity = velocity.move_toward(Vector3.ZERO, 0.99)
	if _is_jumping:
		velocity += Vector3(0, gravity * delta,0)
	else:
		velocity += Vector3(0, -gravity * delta,0)
	move_and_slide()
	var col_count = get_slide_collision_count()
	#if velocity.length() > 0.1:
	#	print(col_count)
	if col_count > 1 and velocity.length() > 0.1:
		for i in range(col_count):
			var collision : KinematicCollision3D = get_slide_collision(i)
			var contactPosition := collision.get_position()
			var contactNormal := collision.get_normal()
			if abs(contactNormal.dot(Vector3.UP)) < 0.5:
				DebugTools.draw_arrow(contactPosition, contactPosition + contactNormal*2.0, Color(1.0, 0.0, 0.0, 1.0), 5.0, i/(col_count))
				#print("Col Num: ", i, "; Col Obj: ", collision.get_collider().get_name(),"; Col Normal: ", contactNormal, "; Col Pos: ", contactPosition)

#	elif position.y > heightStop:
#		velocity += Vector3(0,-gravity*delta,0)
#	else:
#		position.y = heightStop
#		velocity.y = 0.0
#	if inputDirection != Vector2.ZERO:
#		var newDir := Vector3(inputDirection.x,0,inputDirection.y).rotated(Vector3.UP,%CameraController.rotation.y)
##			DebugTools.draw_arrow(position, position+newDir*3.0, Color(1.0, 0.0, 0.0, 1.0), 5.0)
#		velocity += newDir * moveSpeed * delta
#	elif is_on_floor():
#		var downNorm = ray_down_normal(position)
#		if downNorm:
#			var newDir = velocity.slide(downNorm).normalized()
#			DebugTools.draw_arrow(position, position+newDir*3.0, Color(1.0, 0.0, 0.0, 1.0), 5.0)
		
#	move_and_slide()
#	var col_count = get_slide_collision_count()
#	if velocity.length() > 0.1:
#		print(col_count)
#	if col_count > 1 and velocity.length() > 0.1:
#		for i in range(col_count):
#			var collision : KinematicCollision3D = get_slide_collision(i)
#			var contactPosition := collision.get_position()
#			var contactNormal := collision.get_normal()
#			#collision.get_depth()
#			if abs(contactNormal.dot(Vector3.UP)) < 0.5:
#				DebugTools.draw_cube(contactPosition, 0.1, Color(1.0, 0.0, 0.0, 1.0), 5.0, i/(col_count))
#				DebugTools.draw_arrow(contactPosition, contactPosition + contactNormal, Color(1.0, 0.0, 0.0, 1.0), 5.0, i/(col_count))
#				print("Col Num: ", i, "; Col Obj: ", collision.get_collider().get_name(),"; Col Normal: ", contactNormal, "; Col Pos: ", contactPosition)


	#test_move(, velocity, )
#	var time_start = Time.get_ticks_msec()
#	var collisions : KinematicCollision3D = move_and_collide(position+velocity*delta, true, 0.001, false, 1)
#	var time_1 = Time.get_ticks_msec()
#	if collisions:
#		var col_count = collisions.get_collision_count()
#		var new_pos : Vector3
#		if false:
#			for i in range(col_count):
#				var contactName = collisions.get_collider(i).get_name()
#				var contactPosition := collisions.get_position(i)
#				var contactNormal := collisions.get_normal(i).normalized()
#				var contactDist := position.distance_to(contactPosition)
#				var impactDot := -velocity.dot(contactNormal)
#
#				new_pos += contactPosition
#
#				var bounce := contactNormal * (impactDot + 0.0001)
#				print(velocity, "m/s | ", contactDist, "m | ", contactNormal, " * ", impactDot, " = ", bounce)
#				velocity += bounce
#				DebugTools.draw_arrow(contactPosition-(velocity*delta*4), contactPosition, Color(1.0, 0.0, 0.0, 1.0), 5.0, i/(col_count))
#				DebugTools.draw_arrow(contactPosition, contactPosition+(bounce*delta*4), Color(0.0, 1.0, 0.0, 1.0), 5.0, i/(col_count))
#
#				#DebugTools.draw_arrow(contactPosition, contactPosition + contactNormal, Color(1.0, 0.0, 0.0, 1.0), 5.0, i/(col_count))
#				#print("Col Num: ", i, " / ", col_count, "; Col Obj: ", contactName,"; Col Normal: ", contactNormal, "; Col Pos: ", contactPosition)
#			new_pos /= col_count
#		else:
#			var collision_radius = 1.0
#			var contactName = collisions.get_collider(0).get_name()
#			collisions.get
#			var contactPosition := collisions.get_position(0)
#			var contactNormal := collisions.get_normal(0).normalized()
#			var contactDepth := collisions.get_depth()
#			var contactTravel := collisions.get_travel()
#			var contactDist := position.distance_to(contactPosition)
#			var impactDot := -velocity.dot(contactNormal)
#			#contactPosition + velocity
#			new_pos = position + contactTravel
#			var bounce := contactNormal * (impactDot + 0.00)
#
#			#print("Vel: ", velocity, "m/s | Dist: ", contactDist, "m | Depth: ", contactDepth, "m | Norm: ", contactNormal, " * ", impactDot, " = ", bounce)
#			velocity += bounce
#			#DebugTools.draw_arrow(contactPosition-(velocity*delta*4), contactPosition, Color(1.0, 0.0, 0.0, 1.0), 5.0)
#			#DebugTools.draw_arrow(contactPosition, contactPosition+(bounce*delta*4), Color(0.0, 1.0, 0.0, 1.0), 5.0)
#
#
#		position = new_pos+velocity*delta
#		print("Time Check: ", Time.get_ticks_msec() - time_1, ", ", time_1 - time_start)
#	else:
#		position += velocity*delta

func _ready():
	set_up_direction(Vector3.UP)
	_ray_node = get_node("RayCast3D")
	_mesh = get_node("MeshInstance3D")

func _input(event):
	pass
	inputDirection = Input.get_vector("Run_Left", "Run_Right", "Run_Forward", "Run_Back")
	if Input.is_action_pressed("Jump"):
		_is_jumping = true
	else:
		_is_jumping = false
	if Input.is_action_pressed("Mouse_Capture") and Time.get_ticks_msec() > mouseLastEnable + 500:
		mouseLastEnable = Time.get_ticks_msec()
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		mouseDelta = event.relative
		var mouseSensitivity := 0.01
		$CameraController.rotation.x += mouseDelta.y * -mouseSensitivity
		$CameraController.rotation.y += mouseDelta.x * -mouseSensitivity

