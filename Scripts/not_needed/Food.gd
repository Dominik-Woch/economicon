extends Node2D

var resName = "Food" #pozniej
var currAmount
var gatherCost = 2 #pozniej
var regenRate
var capacity # ilu max ludzi może zbierać
onready var sprite = $Sprite
signal harvested

func _ready():
	generate()
	$Name.text = resName
	update_display()
	sprite.material = sprite.material.duplicate()  #make shader unique

func _process(_delta):
	pass

func update_resource():
	currAmount += regenRate
	update_display()


func generate():
	randomize()
	currAmount = 50 * (randi() % 7 + 1) # randi between 50 and 350 with 50 step
	regenRate = ceil(4 * randf()) + 1   # randf [1,5]
	capacity = randi() % 10 + 11        # randi [11,20]

func update_display():
	$CurrentAmount.text = "Available: " + str(floor(currAmount))
	$GatheringCost.text = "Cost: " + str(gatherCost)
	$RegenerationRate.text = "Replenishment: " + str(regenRate)
	$PlaceSize.text = "Capacity: " + str(capacity)

func get_harvested(location, collectors):
	if !is_connected("harvested", location, "end_harvest"):
		connect("harvested", location, "end_harvest")
	
	var amount = min(collectors/gatherCost, currAmount)
	emit_signal("harvested", self, amount, collectors) 
	disconnect("harvested", location, "end_harvest")
	print(amount, " food collected.")
	currAmount = max(0, currAmount - collectors/gatherCost)
	update_display()