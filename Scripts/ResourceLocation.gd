tool
extends "res://Scripts/base_classes/GameResource.gd"
class_name ResourceLocation


onready var name_label: Label = $name
onready var resource_name: String = name_label.text setget _set_resource_name, _get_resource_name
onready var _resource_excav_cost: float = ResourceExcavCost[_resource_type] setget _set_resource_excav_cost, _get_resource_excav_cost
onready var sprite = $Sprite


export(ResourceType) var _resource_type: int = 0 setget _set_resource_type, _get_resource_type


var CYCLE_DURATION: float  = -1.0
var tick_to_depletion: int = 5
var NOT_DEPLETED: bool     = true
var DEPLETING: bool        = false

func _ready():
	if !Engine.is_editor_hint():
		CYCLE_DURATION = get_node("/root/Main").CYCLE_DURATION
	randomize()
#	generate()
	self.resource_name += "_" + str(get_index())
	update_display()
#	harvest_cost = max(1, harvest_cost)
#	cycle = rand_range(0, cycle_length)
	sprite.material = sprite.material.duplicate()


func _set_resource_name(value):
	resource_name = value
	if has_node("name"):
		$name.text = value


func _get_resource_name():
	return resource_name


func _set_resource_excav_cost(value):
	_resource_excav_cost = value


func _get_resource_excav_cost():
	return _resource_excav_cost


func _set_resource_type(value: int):
	_resource_type = value
	if value >= 0:
		_set_resource_name(ResourceName[value])
#		_set_resource_excav_cost(ResourceExcavCost[value]) # nie dzialalo, ustawiam w linii 8
		if has_node("Sprite"):
			$Sprite.texture = load(ResourceSprites[value])
		if value == 0:
			available = 77000
			regenerates_per_cycle = 100
			workforce_capacity = 150
	else:
		_set_resource_name("null resource")
		if has_node("Sprite"):
			$Sprite.texture = load("res://Sprites/No_Resource.png")


func _get_resource_type():
	return _resource_type


func set_resource_size(availabl: float):
	var sc = clamp(availabl/300, 1, 2.5) # 1 ~ 300-, 2 ~ 600, 2.5 ~ 750+
	$Sprite.scale = Vector2(sc, sc)


func _physics_process(delta):
	if !Engine.is_editor_hint(): # do not calculate in editor
		cycle += delta
		if cycle > CYCLE_DURATION and NOT_DEPLETED:
			cycle -= CYCLE_DURATION
#			harvest()
			regenerate()
			update_display()
			consider_total_depletion()
			workforce_total = 0


func regenerate():
	available += regenerates_per_cycle
	available_fluctuations = previous_available - available
	previous_available = available


func consider_total_depletion():
	if available <= regenerates_per_cycle or available <= 0.1 or DEPLETING:
		DEPLETING = true
		tick_to_depletion -= 1
		if tick_to_depletion == 0:
			total_depletion()


func total_depletion():
	NOT_DEPLETED = false
	_set_resource_type(-1)
#	$InfoTable/values.text = "DEPLETED"
	$InfoTable.free()


func update_display():
	$InfoTable/values.text = str(round(available))
	set_resource_size(available)
#	if available < 1: _set_resource_type(-1) # pomysl: opróżnione się zerują
	if available_fluctuations < 0: $InfoTable/values.text += " (+" + str(-round(available_fluctuations*10)/10) + "/s)\n"
	else: $InfoTable/values.text += " (" + str(-round(available_fluctuations*10)/10) + "/s)\n"
	$InfoTable/values.text += str(_resource_excav_cost) + "\n"
	$InfoTable/values.text += str(regenerates_per_cycle) + "\n"
#	$InfoTable/values.text += str(workers_total) + "/" + str(worker_capacity) + "\n"
	$InfoTable/values.text += str(workforce_total) + "/" + str(workforce_capacity) + "\n"
#	$InfoTable/values.text += str(round(stockpile)) + "/" + str(stockpile_max)
#	if stockpile_fluctuations < 0: $InfoTable/values.text += " (+" + str(-round(stockpile_fluctuations*10)/10) + "/s)\n"
#	else: $InfoTable/values.text += " (" + str(-round(stockpile_fluctuations*10)/10) + "/s)\n"


func generate():
	available = 50 * (randi() % 7 + 1)              # randi between 50 and 350 with 50 step
	regenerates_per_cycle = ceil(4 * randf()) + 1   # randf [1,5]
#	worker_capacity = randi() % 10 + 11             # randi [11,20]


#NOTE handled by house.gd, now obsolete
#func harvest():
#	available_fluctuations = available
##	stockpile_fluctuations = previous_stockpile - stockpile
##	previous_stockpile = stockpile
#	available += regenerates_per_cycle
##	var hervested = workers_total / harvest_cost + auto_harvest
#	var hervested = workforce_total / harvest_cost + auto_harvest
#	hervested = min(hervested, harvestable_per_cycle)   #limit by max harvestable
#	hervested = min(hervested, available)               #limit by max available
##	hervested = min(hervested, stockpile_max-stockpile) #limit by max storage
##	stockpile += hervested
#	available -= hervested
#	available_fluctuations -= available
#
#	update_depletion(hervested)
#
#
#func update_depletion(hervested):
#	harvest_cost += available_fluctuations * 0.1
#	harvest_cost = clamp(harvest_cost, 1, harvest_cost_max)