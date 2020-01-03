extends Node2D


onready var gameAge: Label = $HUD/Margin/HBoxContainer/Container/GameAge


const CYCLE_DURATION: float = 1.5


var age: int = 0
var timer = 0
var velocity: Vector2 = Vector2()


func _ready():
	globals.debug = $HUD/TextureRect/Label
	gameAge.text = "Game Age: " + str(age)


func _process(_delta):
	globals.debug.text = "Debug\n"
	timer += _delta
	if timer > CYCLE_DURATION:
		timer -= CYCLE_DURATION
		update_main()


func update_main():
	age += 1
	gameAge.text = "Game Age: " + str(age)
