extends Node2D

var vilName = "Settlement" #pozniej
var population
var idlePopulation
var neededFood
var gatheredFood
var radius = 300 #pozniej
var RAD_SQ = pow(radius, 2)
var neighbours = []
#var neighDstReducedCostSQ = []
onready var sprite = $Sprite
onready var foodPlace = get_parent().get_node("Food")

signal harvesting

func _ready():
	randomize()
	generate()
	$Name.text = vilName
	idlePopulation = population
	update_display()
	detect_neighbours()
	sort_neighbours()
	sprite.material = sprite.material.duplicate() #make shader unique
	
	
func _process(delta):
	if Input.is_action_pressed("print_resources"):
		globals.debug.text += "RESOURCES\n" +str(neighbours) + "\n"
		
func update_village():
	idlePopulation = population
	collect_resources()
	consider_starving()
	neededFood = ceil(population/5)
	consider_birth()
	neededFood = ceil(population/5)
	update_display()

func collect_resources():
	var index = 0
	while(idlePopulation > 0 and index < neighbours.size()):
		print("Starting ", index+1, " harvest of ", get_parent().age, " year.")
		start_harvest(get_cheapest_resource(index))
		index += 1

func start_harvest(location):
	if !is_connected("harvesting", location, "get_harvested"):
		connect("harvesting", location, "get_harvested")
	
	var sentWorkers = min(min(idlePopulation, location.capacity), location.currAmount*location.gatherCost)
	idlePopulation -= sentWorkers
	
	emit_signal("harvesting", self, sentWorkers) 
	disconnect("harvesting", location, "get_harvested")
	print(sentWorkers, " people collecting at", location , ".\n")

func end_harvest(location, amount, sentWorkers):
	gatheredFood += amount
	idlePopulation += sentWorkers
	update_display()

func generate():
	randomize()
	population = randi() % 100 + 1 # randi between 1 and 100
	neededFood = ceil(population/5)
	gatheredFood = randi() % 150 + 251

func consider_starving():
	randomize()
	if gatheredFood >= neededFood: # dość jedzenia - ginie 2-3% pop
		gatheredFood -= neededFood
		if randf() < 0.5:
			population -= round(0.03*population)
		else:
			population -= round(0.02*population)
	else: # mało jedzenia - ginie 20-30% pop (ale nic nie zjadają, poki co)
		if randf() < 0.5:
			population -= max(5, floor(0.3*population))
			population = max(0, population)
		else:
			population -= max(5, floor(0.2*population))
			population = max(0, population)

func consider_birth():
	if gatheredFood >= neededFood: # dość jedzenia - rodzi się 10-15% pop
		gatheredFood -= neededFood
		if randf() < 0.5:
			population += max(1, floor(0.1*population))
		else:
			population += max(1, floor(0.15*population))
	else: # mało jedzenia - rodzi się 0-2% pop
		if randf() < 0.5:
			population += round(0.02*population)

func detect_neighbours(): # array of pairs (Reosurce Node, distance + gather cost)
	for neighbour in get_tree().get_nodes_in_group("resource"):
		var temp = (neighbour.position - position).length_squared()
		if temp < RAD_SQ:
			var pair = [neighbour, floor(0.01*temp) + neighbour.gatherCost]
			neighbours.append(pair)

class MyCustomSorter:
    static func sort(a, b):
        if a[1] < b[1]:
            return true
        return false

func sort_neighbours():
	neighbours.sort_custom(MyCustomSorter, "sort")

func get_cheapest_resource(start = 0):
	print (start+1, " cheapest resource is ", neighbours[start][0], " (", neighbours[start][0].resName, ") with total price = floor(0.01*distanceSQ) + gatherCost = ", neighbours[start][1])
	return neighbours[start][0]


func _draw():
	draw_circle(Vector2(0,0), radius, Color(0.55, 0, 0, 0.3))
	for resource in get_tree().get_nodes_in_group("resource"):
		if resource in neighbours:
			draw_line(Vector2(0,0), resource.position - position, Color(0, 1, 0, 1), 3.0)
		else:
			draw_line(Vector2(0,0), resource.position - position, Color(1, 0, 0, 1), 3.0)

func update_display():
	$Population.text = "Pop: " + str(population)
	$IdlePopulation.text = "Idle: " + str(idlePopulation)
	$Radius.text = "Reach: " + str(radius)
	$NeededFood.text = "Eating: " + str(neededFood)
	$GatheredFood.text = "Possessing: " + str(gatheredFood)