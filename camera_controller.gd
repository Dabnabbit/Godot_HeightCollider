extends Node3D


func _process(delta):
	set_position(%Player.get_position())
