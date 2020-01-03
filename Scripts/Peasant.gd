extends Node2D
class_name Peasant


#var velocity = Vector2()
var destination = Vector2()
var speed_factor: float

var returning = false

func _ready():
	$Sprite/AnimationPlayer.play("run")
	speed_factor = 2 / get_node("/root/Main").CYCLE_DURATION

func _physics_process(delta):
	# for "sending peasants" in one cycle they need to have velocity ~ distance_to_run
	# we want peasant to go 2 * 'destination' distance in one CYCLE_DURATION
	position += speed_factor * destination * delta
	if !returning:
		if position.distance_to(destination) < 5:
			destination = -destination
			$Sprite.set_flip_h(true)
			returning = true
	else:
		if position.distance_to(Vector2.ZERO) < 5:
			queue_free()