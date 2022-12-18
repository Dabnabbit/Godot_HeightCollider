extends Label

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	var player : PlayerController = %Player
	var vel : Vector3 = player.get_linear_velocity()
	var pos : Vector3 = player.get_position()
	var is_pressing_jump : bool = player.player_is_pressing_jump()
	var can_jump : bool = player.player_is_able_to_jump()
	var is_jumping : bool = player.player_is_jumping()
	var on_floor : bool = player.player_get_is_on_floor()
	var time_on_floor : float = player.player_get_time_on_floor()
	var last_on_floor : float = player.player_get_last_on_floor()
#	var on_wall := player.is_on_wall()
#	var on_ceiling := player.is_on_ceiling()
	text = ""
	text += "Velocity:\n  X: {0} \n  Y: {1} \n  Z: {2}".format(["%0.2f" % vel.x, "%0.2f" % vel.y, "%0.2f" % vel.z])
	text += "\nPosition:\n  X: {0} \n  Y: {1} \n  Z: {2}".format(["%0.2f" % pos.x, "%0.2f" % pos.y, "%0.2f" % pos.z])
	text += "\nSpeed: {0} m/s".format(["%0.2f" % vel.length()])
	text += "\nIs_Pressing_Jump: {0}, Can_Jump: {1}, Is_Jumping: {2}".format([is_pressing_jump, can_jump, is_jumping])
	text += "\nOn_Floor: {0}, Time_On_Floor {1}s, Last_On_Floor: {2}s".format([on_floor, "%0.2f" % time_on_floor, "%0.2f" % last_on_floor])
