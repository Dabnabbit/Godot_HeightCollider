@tool

extends Node

const _debug_scene_cube := preload("res://debug_box.tscn")
const _debug_scene_arrow := preload("res://debug_arrow.tscn")
#const _debug_scene_cube := preload("res://debug_cone.tscn")

#//- Spawn Physics objects from Mouse screen coords using activate Camera!
func spawn_physics_from_mouse(type : String, mass : float = 1.0, power : float = 200.0, size : float = 1.0, time : float = 1.0, velocity : Vector3 = Vector3.ZERO):
	var camera : Camera3D = get_viewport().get_camera_3d()
	var screen_coord : Vector2 = get_viewport().get_mouse_position()
	var cam_position : Vector3 = camera.project_position(screen_coord, 0.5)
	var inherit_speed : float = velocity.length()
	if inherit_speed > 1.0:
		velocity = velocity.normalized()
	var cam_vector : Vector3 = camera.project_ray_normal(screen_coord)
	cam_vector = (cam_vector + velocity)
	#var cam_rotation = camera.get_camera_transform().looking_at(cam_vector, Vector3.UP).basis.get_euler()
	match type:
		"cube":
			spawn_physics_cube(cam_position, camera.get_global_rotation(), mass, cam_vector * power, size, time)
		"sphere":
			spawn_physics_sphere(cam_position, mass, cam_vector * power, size, time)
			#draw_arrow(cam_position, cam_position+(cam_vector))

#//- Spawn Physics Cube at position with initial Force
func spawn_physics_cube(pos : Vector3, rot : Vector3, mass : float, force : Vector3, size : float = 1.0, time : float = 1.0):
	var rb := RigidBody3D.new()
	rb.set_mass(mass)
	add_child(rb)
	var rb_collider := CollisionShape3D.new()
	rb.add_child(rb_collider)
	var rb_collider_shape := BoxShape3D.new()
	rb_collider_shape.set_size(Vector3(size, size, size))
	rb_collider.set_shape(rb_collider_shape)
	var rb_mesh := MeshInstance3D.new()
	rb.add_child(rb_mesh)
	var rb_mesh_shape := BoxMesh.new()
	rb_mesh_shape.set_size(Vector3(size, size, size))
	rb_mesh.set_mesh(rb_mesh_shape)
	rb.set_position(pos)
	rb.set_rotation(rot)
	rb.apply_central_force(force)
	var timer_free := Timer.new()
	rb.add_child(timer_free)
	timer_free.timeout.connect(rb.queue_free)
	timer_free.set_wait_time(time)
	timer_free.start()
	rb.set_use_continuous_collision_detection(true)

#//- Spawn Physics Sphere at position with initial Force
func spawn_physics_sphere(pos : Vector3, mass : float, force : Vector3, size : float = 1.0, time : float = 1.0):
	var rb := RigidBody3D.new()
	rb.set_mass(mass)
	add_child(rb)
	var rb_collider := CollisionShape3D.new()
	rb.add_child(rb_collider)
	var rb_collider_shape := SphereShape3D.new()
	rb_collider_shape.set_radius(size*0.5)
	rb_collider.set_shape(rb_collider_shape)
	var rb_mesh := MeshInstance3D.new()
	rb.add_child(rb_mesh)
	var rb_mesh_shape := SphereMesh.new()
	rb_mesh_shape.set_radius(size*0.5)
	rb_mesh_shape.set_height(size)
	rb_mesh.set_mesh(rb_mesh_shape)
	rb.set_position(pos)
	rb.apply_central_force(force)
	var timer_free := Timer.new()
	rb.add_child(timer_free)
	timer_free.timeout.connect(rb.queue_free)
	timer_free.set_wait_time(time)
	timer_free.start()
	rb.set_use_continuous_collision_detection(true)

#//- Draw 3D Point Cube at position
func draw_cube(pos : Vector3, rot : Vector3,  size : float = 1.0, color : Color = Color.WHITE, time : float = 1.0, delay : float = 0.0):
	var debug_scene := _debug_scene_cube.instantiate()
	add_child(debug_scene)
	debug_scene.set_position(pos)
	debug_scene.set_rotation(rot)
	debug_scene.set_scale(Vector3(size, size, size))
	var mesh : MeshInstance3D = debug_scene.get_node("MeshInstance3D")
	var mat : Material = mesh.get_active_material(0).duplicate()
	mat.set_albedo(color)
	mesh.set_surface_override_material(0, mat)
	if delay > 0.0:
		debug_scene.set_visible(false)
		var timer_delay := Timer.new()
		debug_scene.add_child(timer_delay)
		timer_delay.timeout.connect(debug_scene.set_visible.bind(true))
		timer_delay.set_wait_time(delay)
		timer_delay.start()
		
	var timer_free := Timer.new()
	debug_scene.add_child(timer_free)
	timer_free.timeout.connect(mesh.set_surface_override_material.bind(0, null))
	timer_free.timeout.connect(debug_scene.queue_free)
	timer_free.set_wait_time(delay+time)
	timer_free.start()

#//- Draw 3D Vector Arrow between two positions
func draw_arrow(pos1 : Vector3, pos2: Vector3, color : Color = Color.WHITE, time : float = 1.0, delay : float = 0.0):
	var debug_scene := _debug_scene_arrow.instantiate()
	add_child(debug_scene)
	debug_scene.set_position(pos1)
	if abs((pos2-pos1).normalized()).distance_to(Vector3.UP) < 0.001:
		debug_scene.set_position(pos1)
		debug_scene.set_rotation(Vector3(PI/2,0,0))
	else:
		#print(pos2, " - ", pos1, " norm: ",  abs((pos2-pos1).normalized()), " | ", abs((pos2-pos1).normalized()).distance_to(Vector3.UP))
		debug_scene.look_at_from_position(pos1, pos2, Vector3.UP)
	debug_scene.set_scale(Vector3(1, 1, pos1.distance_to(pos2)))
	var mesh : MeshInstance3D = debug_scene.get_node("MeshInstance3D")
	var mat : Material = mesh.get_active_material(0).duplicate()
	mat.set_albedo(color)
	mesh.set_surface_override_material(0, mat)
	if delay > 0.0:
		debug_scene.set_visible(false)
		var timer_delay := Timer.new()
		debug_scene.add_child(timer_delay)
		timer_delay.timeout.connect(debug_scene.set_visible.bind(true))
		timer_delay.set_wait_time(delay)
		timer_delay.start()
		
	var timer_free := Timer.new()
	debug_scene.add_child(timer_free)
	timer_free.timeout.connect(mesh.set_surface_override_material.bind(0, null))
	timer_free.timeout.connect(debug_scene.queue_free)
	timer_free.set_wait_time(delay+time)
	timer_free.start()

#//- Generate _Debug organizer Node at run-time // THIS IS UNNECESSARY LOL NVM
func _ready():
#	if not get_tree().get_current_scene().has_node("_Debug"):
#		_debug_node = Node3D.new()
#		_debug_node.set_name("_Debug")
#		get_tree().get_current_scene().add_child(_debug_node)

	pass
