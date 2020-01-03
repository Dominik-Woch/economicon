tool
extends "res://Scripts/base_classes/Dwelling.gd"
class_name House


enum Actions {KEEPING = -1, BUYING, SELLING}
enum Goods   {FOOD, WOOD, STONE, GOLD}# raczej dict zamaist enuma + basic prices

onready var peasant = load("res://Nodes/Peasant.tscn")
onready var name_label: Label = $name
onready var house_name: String = name_label.text setget _set_house_name, _get_house_name
onready var sprite = $Sprite


export(SettlementType) var _settlement_type:int = 0 setget _set_settlement_type


const SPAWN_DELAY: float = 0.035
const DISTANCE_MULT: float = 0.01 # harvest cost distance multiplier
const HOUSE_COST_WOOD: int = 180
const HOUSE_COST_STONE: int = 100
const BASIC_PRICES: Array = [0.1, 0.2, 0.3] #goods value realted to gold, BASIC_PRICES[Goods.FOOD] = 0.1 etc.

var CYCLE_DURATION: float = -1.0
var RAD_SQ: int = -1
var neighbours: Array = []
var traders: Array = []
var TRADING: Array = []
var BUY_PRICES: Array = []
var SELL_PRICES: Array = []
var starving_factor: float = 0.5
var NEED_MORE_FOOD: bool = false
var NEED_MORE_HOUSES: bool = false


func _ready():
	if !Engine.is_editor_hint():
		CYCLE_DURATION = get_node("/root/Main").CYCLE_DURATION
	randomize()
	RAD_SQ = pow(radius, 2)
	
	prepare_trading_arrays()
	prepare_population_arrays()
	fill_POPULATION_by_age(population_total)
	detect_neighbours()
	sort_neighbours()
	detect_traders()
	sort_traders()
	create_cost_labels()
	self.house_name += "_" + str(get_index())
	update_display()
	sprite.material = sprite.material.duplicate()


func _set_house_name(value):
	house_name = value
	if has_node("name"):
		$name.text = value + "_" + str(get_index())


func _get_house_name():
	return house_name


func _set_settlement_type(value):
	_settlement_type = value
	if value >= 0:
		_set_house_name(SettlementName[value])
		if has_node("Sprite"):
			$Sprite.texture = load(SettlementSprites[value])
	else:
		self.house_name = "null settlement"
		if has_node("Sprite"):
			$Sprite.texture = load("res://Sprites/No_Resource.png")


func _process(delta):
	if !Engine.is_editor_hint():
		cycle += delta
		if cycle > CYCLE_DURATION:
			cycle -= CYCLE_DURATION
			update_village()


"""Calculate wf & fr, then collect. After that starving, accidents, aging birth. wf and fr updated (recalculated)
only at the beginning, population_total updated when changed. Population fluctuations recalcualted only at the beginning."""
func update_village():
	clear_harvesting_workforce()
	calculate_workforce()
	calculate_foodreq()
	collect_resources()
	consider_housing()  # set NEED_MORE_HOUSES (for next year) and NEED_MORE WOOD/STONE for trade
	consider_starving() # set NEED_MORE_FOOD (for next year and trade)
	
	prepare_for_trade()
	trade() # during trade NEED_MORE flags could be overrided
	
	consider_accidents()#
	consider_aging()#
	consider_birth()#
	calculate_fluctuations()
	update_display()
	pass


func calculate_workforce():
	workforce = 0
	for i in range(100):
		workforce += POPULATION_by_age[i] * POPULATION_work_eff[i]
	calculated_workforce = workforce


func calculate_foodreq():
	foodreq = 0
	for i in range(100):
		foodreq += POPULATION_by_age[i] * POPULATION_food_req[i]
	consumption_food = max (1, foodreq) # umarłe osady nie odżywają


"""Harvest food, then harvest remaining res."""
func collect_resources():
	total_workforce_transporting_this_cycle = 0
	if NEED_MORE_FOOD:
		collect_resource_of_type("Food")
		collect_resource_of_type("Berries")
		collect_resource_of_type("Wood")
		collect_resource_of_type("Stone")
	elif NEED_MORE_HOUSES:
		collect_resource_of_type("Wood")
		collect_resource_of_type("Stone")
		collect_resource_of_type("Food")
		collect_resource_of_type("Berries")
	else:
		var temp = randf()
		if temp < 0.5:
			collect_resource_of_type("Food")
			collect_resource_of_type("Berries")
			collect_resource_of_type("Wood")
			collect_resource_of_type("Stone")
		else:
			collect_resource_of_type("Wood")
			collect_resource_of_type("Stone")
			collect_resource_of_type("Food")
			collect_resource_of_type("Berries")


func collect_resource_of_type(type: String):
	for neighbour in neighbours:
			if neighbour[0].resource_name.begins_with(type):
				try_harvest(neighbour[0])


#NOTE transport = move resource from one village to another
"""Need rework for village to village mode."""
#func try_transport(location: ResourceLocation):
#	pass
#	if workforce > 0 and location.stockpile > 0:
#		var transport_cost: float = (position.distance_to(location.position) * 0.002)
#		var workforce_needed_for_max_transport: float = location.stockpile * transport_cost
#		var workforce_transporting: float = min(workforce_needed_for_max_transport, workforce)
#
#		total_workforce_transporting_this_cycle += workforce_transporting#@
#		send_peasants(location.position, workforce_transporting)
#		workforce -= workforce_transporting
###		workforce_reserved_for_transport = max(0, workforce_reserved_for_transport - workforce_transporting)
#		stockpile_food += workforce_transporting/transport_cost
#		location.stockpile -= workforce_transporting/transport_cost
#
###		workforce_needed_for_transport_next_cycle += workforce_needed_for_max_transport
###		workforce_needed_for_transport_next_cycle -= workforce_transporting


#NOTE still nedd rework, changes in base classes (harvest+transport, still capacity)
"""Take resource from the given location and transport it to the village. Transport cost is affected by distance
and resource type (something like 'gathering cost')."""
func try_harvest(location: ResourceLocation):
	if workforce > 0 and location.available > 1:
		if location.workforce_total < location.workforce_capacity:
				
				var harvest_cost = (position.distance_to(location.position) * DISTANCE_MULT) * location._resource_excav_cost
				var max_workforce_allocation = location.workforce_capacity - location.workforce_total
				var workforce_needed_for_max_harvest: float = location.available * harvest_cost
				
				var workforce_allocation: float = min(workforce, workforce_needed_for_max_harvest)
				workforce_allocation = min(max_workforce_allocation, workforce_allocation)
				workforce -= workforce_allocation
				location.workforce_total += workforce_allocation #NOTE Zerowane co update wszystkim wioskom
				location.update_display() #NOTE trochę hack
				neighbours[find_neighbour_idx(location)][2] += workforce_allocation #NOTE Do poprawy ten 3 el tablicy
				workforce_collecting += workforce_allocation#@ juz nie collectiing
				
				send_peasants(location.position, workforce_allocation)
				if location._get_resource_type() == 0 or location._get_resource_type() == 1:
					stockpile_food += workforce_allocation/harvest_cost
				elif location._get_resource_type() == 2:
					stockpile_wood += workforce_allocation/harvest_cost
				elif location._get_resource_type() == 3:
					stockpile_stone += workforce_allocation/harvest_cost
				location.available -= workforce_allocation/harvest_cost


func clear_harvesting_workforce():
	for neighbour in neighbours:
		neighbour[2] = 0


func find_neighbour_idx(location: ResourceLocation) -> int:
	for idx in range(neighbours.size()):
		if (neighbours[idx][0] as ResourceLocation) == location:
			return idx
	return -1


func find_trader_idx(location: House) -> int:
	for idx in range(traders.size()):
		if (traders[idx][0] as House) == location:
			return idx
	return -1


func generate():
	population_total = randi() % 100 + 1 # randi between 1 and 100
	stockpile_food = randi() % 150 + 251


func consider_housing():
	housing_req_total = calculate_housing_req()
	if foodreq != 0:
		population_birth_multiplier = clamp(stockpile_food/foodreq, 0.15, 0.5) + clamp(housing - housing_req_total, 0, 1)
	else:
		population_birth_multiplier = 0.5 + clamp(housing - housing_req_total, 0, 1)
	# housing rośnie jak budujemy domy, 1 dom = 100 kamienia lub 180 drewna
	# jeśli w tym roku brakowało miejsca, to (jeśli są surki) zacznij budować domy (tak by na przyszły rok były gotowe)
	if housing < housing_req_total:
		var needed_houses = housing_req_total - housing
		var possible_to_build = floor(stockpile_wood/HOUSE_COST_WOOD) + floor(stockpile_stone/HOUSE_COST_STONE)
		if possible_to_build < needed_houses:
			NEED_MORE_HOUSES = true
		else:
			NEED_MORE_HOUSES = false
		if possible_to_build > 0:
			for i in range(min(needed_houses, possible_to_build)):
				if stockpile_wood >= HOUSE_COST_WOOD:
					stockpile_wood -= HOUSE_COST_WOOD
					housing += 1
				elif stockpile_stone >= HOUSE_COST_STONE:
					stockpile_stone -= HOUSE_COST_STONE
					housing += 1
	else:
		NEED_MORE_HOUSES = false


func calculate_housing_req() -> float:
	var temp = 0.0
	for i in range(100):
		temp += POPULATION_by_age[i] * POPULATION_housing_req[i]
	return temp


func prepare_for_trade():
#	Założenia: 
#	- płacimy zawsze "złotem", nie ma barteru
#	- złoto ma wartość = 1.0
#	- jedzenie chcemy kupować jak nam za szybko ubywa
#	- kamień/drewno chcemy kupować jak mamy za mało domów
#	- wtedy "naiwnie" skupujemy i drewno i kamień
#	- jedzenie chcemy sprzedawać jak nam przybywa (nie przejadamy)
#	- kamień/drewno chcemy sprzedawać jak mamy dość domów
#	- chcemy zachowywać minimalny zapas towarów, nie sprzedawać do zera
#	- każdy rozpatruje handel z każdym, co symuluje sytuację "wezmę złoto/towar i pojadę do ciebie !!!
#   (może się zdarzyć, że ludzie z wioski A jadą do B i z B jadą do A bo jedni mają u siebie coś a drudzy coś)
#
#   TRADING[Goods.FOOD] = TRADING[0]
#                  FOOD              WOOD            STONE
	TRADING = [Actions.KEEPING, Actions.KEEPING, Actions.KEEPING]  # clear previous trade
	
	# check bool flags to determine what village needs, based on that set buying selling keepnig
	for i in range(3):
		check_resource(i)
	
	#maby mess with transaction prices
#	for i in range(TRADING.size()):
#		if TRADING[i] == Actions.SELLING:
#			SELL_PRICES[i] = 
#		elif TRADING[i] == Actions.BUYING:
#			BUY_PRICES[i] = 


func check_resource(res_idx):
	var stockpile_fluctuations
	var NEED_MORE
	if res_idx == 0:
		stockpile_fluctuations = stockpile_food_fluctuations
		NEED_MORE = NEED_MORE_FOOD
	elif res_idx == 1:
		stockpile_fluctuations = stockpile_wood_fluctuations
		NEED_MORE = NEED_MORE_HOUSES
	elif res_idx == 2:
		stockpile_fluctuations = stockpile_stone_fluctuations
		NEED_MORE = NEED_MORE_HOUSES
	if stockpile_fluctuations < 0: # operating on data from last year, fluct < 0 means "we are on + food income"
		if NEED_MORE:
			TRADING[res_idx] = Actions.KEEPING
		else:
			TRADING[res_idx] = Actions.SELLING
	else:
		if stockpile_gold > 0:
			TRADING[res_idx] = Actions.BUYING
		else:
			TRADING[res_idx] = Actions.KEEPING


func trade():
	for i in range(3): # for every resource, i = 0 ~ Goods.FOOD etc.
		#sort nearby traders by buy/sell resource value (depending on your own action)
		trade_sort(i)
		for trader in traders:
			consider_resource(trader, i)
	pass


func trade_sort(res_idx):
	if TRADING[res_idx] == Actions.SELLING: # chcemy iść najpierw do tych, co najdrożej kupią
		sort_traders(2, res_idx) # więc sortujemy malejąco po cenach kupna #NOTE po niższych czy wyższych potem ogarnij
	elif TRADING[res_idx] == Actions.BUYING: # chcemy iść najpierw do tych, co najtaniej sprzedadzą
		sort_traders(3, res_idx) # więc sortujemy rosnąco po cenach sprzedaży


func consider_resource(trader, res_idx):
	# póki co handlujemy z pierwszym akceptowalnym z brzegu, bez porównywania cen
	# ale będzie je trzeba robić gdzieś wcześniej na fazie wyboru
	if TRADING[res_idx] == Actions.SELLING:
		# porownaj swoje sell prices z location buy prices
		if SELL_PRICES[res_idx] <= trader[0].BUY_PRICES[res_idx]: # najtaniej jak sprzedam <= najdrożej jak kupi
			# to się dogadamy wyliczając średnią z naszych (pokrywających się) przedziałów
			var transaction_price = (SELL_PRICES[res_idx] + trader[0].BUY_PRICES[res_idx])/2
			var max_sell_value_in_gold
			if res_idx == Goods.FOOD:
				max_sell_value_in_gold = stockpile_food * transaction_price
			elif res_idx == Goods.WOOD:
				max_sell_value_in_gold = stockpile_wood * transaction_price
			elif res_idx == Goods.STONE:
				max_sell_value_in_gold = stockpile_stone * transaction_price
			var max_buy_owned_gold = trader[0].stockpile_gold
			var max_transaction = min(max_sell_value_in_gold, max_buy_owned_gold)
			
			# actual trade
			if max_transaction >= 0.01: # the smallest deal system will accept
				if res_idx == Goods.FOOD:
					stockpile_food -= max_transaction / transaction_price
					trader[0].stockpile_food += max_transaction / transaction_price
				elif res_idx == Goods.WOOD:
					stockpile_wood -= max_transaction / transaction_price
					trader[0].stockpile_wood += max_transaction / transaction_price
				elif res_idx == Goods.STONE:
					stockpile_stone -= max_transaction / transaction_price
					trader[0].stockpile_stone += max_transaction / transaction_price
				
				stockpile_gold += max_transaction
				trader[0].stockpile_gold -= max_transaction
				
				#dostosuj ceny w zależności od tego co się stało 
				#  SELL_PRICE = 0.2, trader/BUY_PRICE = 0.4 -> transaction_price = 0.3
				#        0.2         += 0.2 * (       0.3        -         0.2         )
				SELL_PRICES[res_idx] += 0.2 * (transaction_price - SELL_PRICES[res_idx])
				trader[0].BUY_PRICES[res_idx] -= 0.2 * (trader[0].BUY_PRICES[res_idx] - transaction_price)
				
				#actualize NEED MORE flags (if satisfied stop buying/selling)
				check_need_more_flags(res_idx)
				
				print($name.text, " sold ", (max_transaction / transaction_price), " resource ", res_idx, " to ",\
				      trader[0].get_node("name").text, " for ", max_transaction, " gold, unit price was ", transaction_price)
	elif TRADING[res_idx] == Actions.BUYING: # buy 0.9, 1    # sell 1.1, 1
		# porownaj swoje buy prices z location sell prices
		if BUY_PRICES[res_idx] >= trader[0].SELL_PRICES[res_idx]: # najdrożej jak kupię >= najtaniej jak sprzeda
			# to się dogadamy wyliczając średnią z naszych (pokrywającyh się) przedziałów
			var transaction_price = (BUY_PRICES[res_idx] + trader[0].SELL_PRICES[res_idx])/2
			var max_sell_value_in_gold
			if res_idx == Goods.FOOD:
				max_sell_value_in_gold = trader[0].stockpile_food * transaction_price
			elif res_idx == Goods.WOOD:
				max_sell_value_in_gold = trader[0].stockpile_wood * transaction_price
			elif res_idx == Goods.STONE:
				max_sell_value_in_gold = trader[0].stockpile_stone * transaction_price
			
			var max_buy_owned_gold = stockpile_gold
			var max_transaction = min(max_sell_value_in_gold, max_buy_owned_gold)
			
			# actual trade
			if max_transaction >= 0.01: # the smallest deal system will accept
				if res_idx == Goods.FOOD:
					stockpile_food += max_transaction / transaction_price
					trader[0].stockpile_food -= max_transaction / transaction_price
				elif res_idx == Goods.WOOD:
					stockpile_wood += max_transaction / transaction_price
					trader[0].stockpile_wood -= max_transaction / transaction_price
				elif res_idx == Goods.STONE:
					stockpile_stone += max_transaction / transaction_price
					trader[0].stockpile_stone -= max_transaction / transaction_price
				stockpile_gold -= max_transaction
				trader[0].stockpile_gold += max_transaction
				
				BUY_PRICES[res_idx] -= 0.2 * (BUY_PRICES[res_idx] - transaction_price)
				trader[0].SELL_PRICES[res_idx] += 0.2 * (transaction_price - trader[0].SELL_PRICES[res_idx])
				
				#actualize NEED MORE flags (if satisfied stop buying/selling)
				check_need_more_flags(res_idx)
				
				print($name.text, " bought ", (max_transaction / transaction_price), " resource ", res_idx, " from ",\
				      trader[0].get_node("name").text, " for ", max_transaction, " gold, unit price was ", transaction_price)


func check_need_more_flags(res_idx):
	if res_idx == 0:
		if stockpile_food > 3 * consumption_food: NEED_MORE_FOOD = false # chcemy miec zdrowy 3 letni zapaas
		else: NEED_MORE_FOOD = true
		check_resource(Goods.FOOD)
	elif res_idx == 1:
		if stockpile_wood >= HOUSE_COST_WOOD: NEED_MORE_HOUSES = false # chcemy miec zdrowy 1 domowy zapas
		else: NEED_MORE_HOUSES = true
		check_resource(Goods.WOOD)
	elif res_idx == 2:
		if stockpile_stone >= HOUSE_COST_STONE: NEED_MORE_HOUSES = false # chcemy miec zdrowy 1 domowy zapas
		else: NEED_MORE_HOUSES = true
		check_resource(Goods.STONE)
		
	#NOTE trades messing with resource_fluctuation prob needed workaround


func consider_starving():
	if stockpile_food >= consumption_food: # dość jedzenia, nie rób nic
		if stockpile_food > 4 * consumption_food: NEED_MORE_FOOD = false # chcemy miec zdrowy 3 letni zapaas
		else: NEED_MORE_FOOD = true
		stockpile_food -= consumption_food
	elif population_total > 0: # za mało jedzenia, zjadają co jest i umierają proporcjonalnie do brakującej żywności
		NEED_MORE_FOOD = true
		var food_missing = consumption_food - stockpile_food
		var consumption_food_missing_percentage = food_missing / consumption_food # need 100, got 70 so missing 30%
		stockpile_food = 0
		
		# brakuje 30%, więc umiera 30% * starvFactor POPULACJI a nie FOODREQ więc czasem więcej a czasem mniej
		
		var amount = max(1, floor(consumption_food_missing_percentage * starving_factor * population_total))
		for i in range(amount):
			kill_random_citizen() # do not decrease workforce and foodreq -> no need


func consider_birth(): #NOTE w/o birthrate for now, TODO
# how birthrate should work? pairs, age difference, or ignore
	var amount
	if stockpile_food >= consumption_food: # dość jedzenia - rodzi się 10 v 15% pop
		stockpile_food -= consumption_food
		if randf() < 0.5:
			amount = max(1, floor(0.1 * population_total))
			population_total += amount
			for i in range(amount):
				POPULATION_by_age[0] += 1
		else:
			amount = max(1, floor(0.15 * population_total))
			population_total += amount
			for i in range(amount):
				POPULATION_by_age[0] += 1
			
	else: # mało jedzenia - rodzi się 0 v 2% pop
		if randf() < 0.5:
			amount = round(0.02 * population_total)
			population_total += amount
			for i in range(amount):
				POPULATION_by_age[0] += 1


func consider_accidents(): 
# death should decrease workforce, but if we do not transprot or harvest
# later in this cycle, we can ignore it bec we recalculate at the beginning anyway
	for i in range(100):
		if POPULATION_by_age[i] > 0:
			var number_of_possible_accidents = POPULATION_by_age[i]
			for j in range(number_of_possible_accidents):
				if randf() < POPULATION_death_rate[i]:
					POPULATION_by_age[i] -= 1
					####### every death/birth should actualize workforce and food req? NOPE
					# workforce -= POPULATION_work_eff[i]
#					neighbour[0].workers_total -= 1 # czasami, ale to trzeba zerować co cykl i tak i nie trackujemy juz
					#######
					population_total -= 1


"""If sb somehow reacheas age of 100 years - sb need to die. Every person ages."""
func consider_aging(): # Assumption: aging after starving
	population_total -= POPULATION_by_age[99]
	for i in range (99, 0, -1): # i = 99; i > 0; i--
		POPULATION_by_age[i] = POPULATION_by_age[i-1]
	POPULATION_by_age[0] = 0
	update()


func calculate_fluctuations():
	calculated_workforce_fluctuations = previous_calculated_workforce - calculated_workforce
	previous_calculated_workforce = calculated_workforce
	
	population_total_fluctuations = previous_population_total - population_total
	previous_population_total = population_total
	
	stockpile_food_fluctuations = previous_stockpile_food - stockpile_food
	previous_stockpile_food = stockpile_food
	
	stockpile_wood_fluctuations = previous_stockpile_wood - stockpile_wood
	previous_stockpile_wood = stockpile_wood
	
	stockpile_stone_fluctuations = previous_stockpile_stone - stockpile_stone
	previous_stockpile_stone = stockpile_stone


"""Decrement random cell in POPULATION_by_age by one, besides that affect population_total counter only.
The idea is to call this function in proper context, alongside with decreasement 
of corresponding variabiles."""
func kill_random_citizen():
	if population_total > 0:
		for i in range(10):
			var temp = randi() % 100
			if POPULATION_by_age[temp] > 0:
				POPULATION_by_age[temp] -= 1
				population_total -= 1
				return
		var a = 0
		var b = 99
		while(true): # if cannot find random age citizen in 10 attempts, kill youngest/oldest citizen
			if POPULATION_by_age[a] > 0:
				POPULATION_by_age[a] -= 1
				population_total -= 1
				return
			if POPULATION_by_age[b] > 0:
				POPULATION_by_age[b] -= 1
				population_total -= 1
				return
			a += 1
			b -= 1


func send_peasants(where: Vector2, how_much: float = 1.0):
	
	how_much = floor(how_much) # since peasants are now workforce, for visualization we ignore .x
	var how_much_fifty = 0
	var how_much_twenty = 0
	var how_much_ten = 0
	
	if how_much >= 50:
		how_much_fifty = floor(how_much/50)
		how_much -= 50 * how_much_fifty
	
	if how_much >= 20:
		how_much_twenty = floor(how_much/20)
		how_much -= 20 * how_much_twenty
	
	if how_much >= 10:
		how_much_ten = floor(how_much/10)
		how_much -= 10 * how_much_ten
	
	if how_much_fifty > floor(0.5 * float(CYCLE_DURATION)/SPAWN_DELAY): # currently > 21
		# needed only if we create resources with huge (1050+) workspace capacity
		print("Need proper handling for huge workforce amount.")
		how_much_fifty = floor(0.5 * float(CYCLE_DURATION)/SPAWN_DELAY)
		how_much_twenty = 0
		how_much_ten = 0
		how_much = 0
	
	var total_peasants = how_much_fifty + how_much_twenty + how_much_ten + how_much
	
	if total_peasants > floor(0.5 * float(CYCLE_DURATION)/SPAWN_DELAY):
		# total_peasants peak value for 10 1 1 9 or 10 2 0 9 (10 x 50, 1 x 20 etc.)
		# so eventeual problems starting from 539 and 549 
		if total_peasants - how_much > floor(0.5 * float(CYCLE_DURATION)/SPAWN_DELAY): # not last digit fault alone
			# 19 1 1 0 (989) or 19 2 0 0 (999), is not likely to happen but well (smallest troublemakers)
			print("SPAWN PEASANTS WEIRD COINCIDENCE")
			how_much_fifty = floor(0.5 * float(CYCLE_DURATION)/SPAWN_DELAY)
			how_much_twenty = 0
			how_much_ten = 0
			how_much = 0
		else:
			# since it is just visualization ignore few x1 peasants
			how_much -= (total_peasants - floor(0.5 * float(CYCLE_DURATION)/SPAWN_DELAY))
			total_peasants -= (total_peasants - floor(0.5 * float(CYCLE_DURATION)/SPAWN_DELAY))
	
	if how_much_fifty > 0:
		yield(get_tree().create_timer(SPAWN_DELAY), "timeout")
		send_group(how_much_fifty, where, 1.6, Color(0, 0.5, 0.7, 1))
	
	if how_much_twenty > 0:
		yield(get_tree().create_timer(SPAWN_DELAY), "timeout")
		send_group(how_much_twenty, where, 1.4, Color(0.9, 0.5, 0.5, 1))
	
	if how_much_ten > 0:
		yield(get_tree().create_timer(SPAWN_DELAY), "timeout")
		send_group(how_much_ten, where, 1.2, Color(0.7, 1, 0, 1))
	
	if how_much > 0:
		yield(get_tree().create_timer(SPAWN_DELAY), "timeout")
		send_group(how_much, where)
	
#	for i in range(how_much_fifty):
#		yield(get_tree().create_timer(SPAWN_DELAY), "timeout")
#		var peasant_instance = peasant.instance()
#		peasant_instance.position = Vector2.ZERO
#		peasant_instance.destination = (where - position)
#		var angle_rad = Vector2.RIGHT.angle_to(peasant_instance.destination)
#		peasant_instance.rotation = angle_rad
#		if angle_rad > 0.5 * PI and angle_rad < 1.5 * PI:
#			peasant_instance.get_node("Sprite").set_flip_v(true)
#		peasant_instance.scale = Vector2(1.6, 1.6)
#		peasant_instance.get_node("Sprite").modulate = Color(0, 0.5, 0.7, 1)
#		add_child(peasant_instance)
#
#	for i in range(how_much_twenty):
#		yield(get_tree().create_timer(SPAWN_DELAY), "timeout")
#		var peasant_instance = peasant.instance()
#		peasant_instance.position = Vector2.ZERO
#		peasant_instance.destination = (where - position)
#		var angle_rad = Vector2.RIGHT.angle_to(peasant_instance.destination)
#		peasant_instance.rotation = angle_rad
#		if angle_rad > 0.5 * PI and angle_rad < 1.5 * PI:
#			peasant_instance.get_node("Sprite").set_flip_v(true)
#		peasant_instance.scale = Vector2(1.4, 1.4)
#		peasant_instance.get_node("Sprite").modulate = Color(0.9, 0.5, 0.5, 1)
#		add_child(peasant_instance)
#
#	for i in range(how_much_ten):
#		yield(get_tree().create_timer(SPAWN_DELAY), "timeout")
#		var peasant_instance = peasant.instance()
#		peasant_instance.position = Vector2.ZERO
#		peasant_instance.destination = (where - position)
#		var angle_rad = Vector2.RIGHT.angle_to(peasant_instance.destination)
#		peasant_instance.rotation = angle_rad
#		if angle_rad > 0.5 * PI and angle_rad < 1.5 * PI:
#			peasant_instance.get_node("Sprite").set_flip_v(true)
#		peasant_instance.scale = Vector2(1.2, 1.2)
#		peasant_instance.get_node("Sprite").modulate = Color(0.7, 1, 0, 1)
#		add_child(peasant_instance)
#
#	for i in range(how_much):
#		yield(get_tree().create_timer(SPAWN_DELAY), "timeout")
#		var peasant_instance = peasant.instance()
#		peasant_instance.position = Vector2.ZERO
#		peasant_instance.destination = (where - position)
#		var angle_rad = Vector2.RIGHT.angle_to(peasant_instance.destination)
#		peasant_instance.rotation = angle_rad
#		if angle_rad > 0.5 * PI and angle_rad < 1.5 * PI:
#			peasant_instance.get_node("Sprite").set_flip_v(true)
#		add_child(peasant_instance)


func send_group(how_many: int, where, size: float = 1.0, color: Color = Color(1, 1, 1, 1)):
	for i in range(how_many):
		yield(get_tree().create_timer(SPAWN_DELAY), "timeout")
		var peasant_instance = peasant.instance()
		peasant_instance.position = Vector2.ZERO
		peasant_instance.destination = (where - position)
		var angle_rad = Vector2.RIGHT.angle_to(peasant_instance.destination)
		peasant_instance.rotation = angle_rad
		if angle_rad > 0.5 * PI and angle_rad < 1.5 * PI:
			peasant_instance.get_node("Sprite").set_flip_v(true)
		peasant_instance.scale = Vector2(size, size)
		peasant_instance.get_node("Sprite").modulate = color
		add_child(peasant_instance)


func prepare_trading_arrays():
	TRADING = [Actions.KEEPING, Actions.KEEPING, Actions.KEEPING, Actions.KEEPING] # TRADING[Goods.FOOD] = KEEPING etc.
	BUY_PRICES.clear()
	SELL_PRICES.clear()
	for i in range(BASIC_PRICES.size()):
		var buy_price = BASIC_PRICES[i] * (1 + 2*randf()) # max gold this village is willling to buy for [BP, 3BP]
		BUY_PRICES.append(buy_price)
		
		var sell_price = BASIC_PRICES[i] * (0.9 + 0.2*randf()) # min gold this village is willing to sell for [0.9BP, 1.1BP]
		SELL_PRICES.append(sell_price)


func prepare_population_arrays():
	prepare_array(POPULATION_by_age, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
	
#	POPULATION_food_req    = [0.0, 0.0, 0.0, 0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6,
#	                          0.7, 0.7, 0.7, 0.7, 0.7, 0.8, 0.8, 0.9, 0.9, 0.9, 
#	                          1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 
#	                          1.0, 1.0, 1.0, 1.0, 1.0, 0.9, 0.9, 0.9, 0.9, 0.9, 
#	                          0.8, 0.8, 0.8, 0.8, 0.8, 0.7, 0.7, 0.7, 0.7, 0.7,
#	                          0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6,
#	                          0.6, 0.6, 0.6, 0.6, 0.6, 0.5, 0.5, 0.5, 0.5, 0.5,
#	                          0.4, 0.4, 0.4, 0.4, 0.4, 0.4, 0.4, 0.4, 0.4, 0.4,
#	                          0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 
#	                          0.3, 0.3, 0.3, 0.3, 0.3, 0.2, 0.2, 0.2, 0.2, 0.2]
	POPULATION_food_req    = [0.0, 0.0, 0.0, 0.0, 0.05, 0.1, 0.15, 0.2, 0.25, 0.3,
	                          0.35, 0.35, 0.35, 0.35, 0.35, 0.4, 0.4, 0.45, 0.45, 0.45, 
	                          0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 
	                          0.5, 0.5, 0.5, 0.5, 0.5, 0.45, 0.45, 0.45, 0.45, 0.45, 
	                          0.4, 0.4, 0.4, 0.4, 0.4, 0.35, 0.35, 0.35, 0.35, 0.35,
	                          0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3,
	                          0.3, 0.3, 0.3, 0.3, 0.3, 0.25, 0.25, 0.25, 0.25, 0.25,
	                          0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2,
	                          0.15, 0.15, 0.15, 0.15, 0.15, 0.15, 0.15, 0.15, 0.15, 0.15, 
	                          0.15, 0.15, 0.15, 0.15, 0.15, 0.1, 0.1, 0.1, 0.1, 0.1]
	
	POPULATION_work_eff    = [0.0, 0.0, 0.0, 0.0, 0.1, 0.2, 0.3, 0.4, 0.4, 0.4,
	                          0.5, 0.5, 0.6, 0.6, 0.7, 0.7, 0.8, 0.8, 0.9, 0.9,
	                          1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 
	                          1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 
	                          0.9, 0.9, 0.9, 0.9, 0.9, 0.8, 0.8, 0.8, 0.8, 0.8,
	                          0.7, 0.7, 0.7, 0.7, 0.7, 0.6, 0.6, 0.6, 0.6, 0.6,
	                          0.5, 0.5, 0.5, 0.5, 0.5, 0.4, 0.4, 0.4, 0.4, 0.4,
	                          0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3,
	                          0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3,  
	                          0.2, 0.2, 0.2, 0.2, 0.2, 0.1, 0.1, 0.1, 0.1, 0.1]
	
	POPULATION_death_rate  = [0.35, 0.2, 0.15, 0.1, 0.05, 0.01, 0.01, 0.01, 0.01, 0.01, 
	                          0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01,
	                          0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 
	                          0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 
	                          0.03, 0.03, 0.03, 0.03, 0.03, 0.03, 0.03, 0.03, 0.03, 0.03, 
	                          0.04, 0.04, 0.04, 0.04, 0.04, 0.04, 0.04, 0.04, 0.04, 0.04, 
	                          0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 
	                          0.07, 0.07, 0.07, 0.07, 0.07, 0.07, 0.07, 0.07, 0.07, 0.07, 
	                          0.09, 0.09, 0.09, 0.09, 0.09, 0.09, 0.09, 0.09, 0.09, 0.09, 
	                          0.11, 0.13, 0.15, 0.17, 0.19, 0.21, 0.23, 0.25, 0.27, 0.30]
	
#	prepare_array(POPULATION_male_ratio, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5) # jak i kiedy modyfikowane
	
#	prepare_array(POPULATION_birth_rate, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
# 1 dom = ~~ 5 osób dorosłych, dzieci <= 9 lat to 1/4 doroslego, <= 18 to 1/2
	POPULATION_housing_req = [0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.1, 
	                          0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.2, 0.2, 
	                          0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 
	                          0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 
	                          0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 
	                          0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2,
	                          0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 
	                          0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2,
	                          0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 
	                          0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2]


func prepare_array(array, v1_10, v11_20, v21_30, v31_40, v41_50, v51_60, v61_70, v71_80, v81_90, v91_100):
	array.resize(0)
	for i in range(0, 10): # od [0] = 1 do [9] = 10
		array.push_back(v1_10)
	for i in range(10, 20): # wiek 11 - 20
		array.push_back(v11_20)
	for i in range(20, 30): # wiek 21 - 30
		array.push_back(v21_30)
	for i in range(30, 40): # wiek 31 - 40
		array.push_back(v31_40)
	for i in range(40, 50): # etc
		array.push_back(v41_50)
	for i in range(50, 60):
		array.push_back(v51_60)
	for i in range(60, 70):
		array.push_back(v61_70)
	for i in range(70, 90):
		array.push_back(v71_80)
	for i in range(80, 90):
		array.push_back(v81_90)
	for i in range(90, 100):
		array.push_back(v91_100)


func detect_neighbours(): # Neighbour = triple [Reosurce Node, distance, amount of this settlement workforce]
	neighbours.clear()
	for resource in get_tree().get_nodes_in_group("resource"):
		var resource_idx = find_neighbour_idx(resource)
		if position.distance_squared_to(resource.position) < RAD_SQ:
			if resource_idx == -1: # jest a zasięgu, nie ma w tablicy -> dodaj
				var triple = [resource, position.distance_to(resource.position), 0]
				neighbours.append(triple)
		else:
			if resource_idx != -1: # jest w tablicy, nie ma w zasięgu -> usuń i wyzeruj workforce? tylko po co w sumie
				resource.workforce_total -= neighbours[resource_idx][2]###
#				neighbours[resource_idx][2] = 0 # niepotrzebne
				neighbours.remove(resource_idx)


func detect_traders(): # Trader = triple [Village Node, distance, buy prices, sell prices]
	traders.clear()
	for village in get_tree().get_nodes_in_group("village"):
		var village_idx = find_trader_idx(village)
		if position.distance_squared_to(village.position) < 1.9 * RAD_SQ:
			if village != self and village_idx == -1: # jest a zasięgu, nie ma w tablicy -> dodaj
				var quadruple = [village, position.distance_to(village.position), village.BUY_PRICES, village.SELL_PRICES]
				traders.append(quadruple)
		else:
			if village_idx != -1: # jest w tablicy, nie ma w zasięgu -> usuń i wyzeruj workforce? tylko po co w sumie
				traders.remove(village_idx)


func create_cost_labels():
	var node = Node2D.new()
	node.name = "CostLabels"
	node.z_index = 1
#	get_tree().get_root().call_deferred("add_child", node)
	add_child(node)
	for resource in get_tree().get_nodes_in_group("resource"):
		var label = Label.new()
		label.name = resource.name
		if position.distance_squared_to(resource.position) < 2 * RAD_SQ:
			label.text = str(stepify(position.distance_to(resource.position), 0.1))
		else:
			label.text = ""
		label.rect_position = 0.5*(resource.position - position)
		label.add_font_override("font",load("res://Fonts/Jamma_13.tres"))
		node.add_child(label)


func update_cost_labels(node):
	for resource in get_tree().get_nodes_in_group("resource"):
		var label_node = get_node(node+"/"+resource.name) as Label
		if resource._resource_type == -1 or position.distance_squared_to(resource.position) >= 2 * RAD_SQ:
			label_node.text = "" # hide, not delete
		else:
			label_node.text = str(stepify(position.distance_to(resource.position), 0.1))
			label_node.rect_position = 0.5*(resource.position - position)


func calculate_workers_share(our_workers: int, total_workers: int):
	if total_workers != 0:
		return str(stepify(100 * (float(our_workers)/total_workers), 0.01)) + "%"
	else:
		return "0%"

func neighbours_info():
	var temp: String = ""
	var index: int = 0
	for neighbour in neighbours:
		index += 1
		temp += str(index) + ". " + str(neighbour[0].resource_name) + "\n"
		temp += "Harvest cost = " + str(neighbour[1] * DISTANCE_MULT * neighbour[0]._resource_excav_cost) + "\n"
		temp += "Excav cost = " + str(neighbour[0]._resource_excav_cost) + "\n"
		temp += "Occupying " + str(neighbour[2]) + "/" + str(neighbour[0].workforce_capacity) + " wf space.\n"
		temp += "Workforce share = " + calculate_workers_share(neighbour[2], neighbour[0].workforce_total) + "\n"
	return temp


func traders_info():
	var temp: String = ""
	var index: int = 0
	for trader in traders:
		index += 1
		temp += str(index) + ". " + str(trader[0].get_node("name").text) + "\n"
#		temp += "Harvest cost = " + str(trader[1] * DISTANCE_MULT * trader[0]._resource_excav_cost) + "\n"
#		temp += "Excav cost = " + str(trader[0]._resource_excav_cost) + "\n"
#		temp += "Occupying " + str(trader[2]) + "/" + str(trader[0].workforce_capacity) + " wf space.\n"
#		temp += "Workforce share = " + calculate_workers_share(trader[2], trader[0].workforce_total) + "\n"
	return temp


"""Sort (2+)-dimensional array by 2nd value"""
class MyCustomSorter:
	static func sort(a, b):
		if a[1] < b[1]:
			return true
		return false


"""Sort traders by buy/sell value"""
class MyCustomTraderSorter:
	static func sort_buy_food(a, b): #sortujemy po cenach "za ile kupię", chcemy by kupowali drogo -> desc
#		if a[2][0][0] > b[2][0][0]:
		if a[2][0] > b[2][0]:
			return true
		return false
	static func sort_sell_food(a, b): #asc
#		if a[3][0][0] < b[3][0][0]:
		if a[3][0] < b[3][0]:
			return true
		return false


""" mean = mean human age, deviation in years too"""
func fill_POPULATION_by_age(pop, mean: float = 30.0, deviation: float = 5.0): # 68% [25, 35] 95% [20, 40], 99.7% [15, 45]
	var temp
	for i in range(pop):
		temp = gaussian(mean, deviation)
		POPULATION_by_age[int(clamp(temp, 0, 100))] += 1


func gaussian(mean, deviation) -> float:
	var x1 = null
	var x2 = null
	var w = null
	
	while true:
		x1 = rand_range(0, 2) - 1 # [-1, 1]
		x2 = rand_range(0, 2) - 1
		w = x1*x1 + x2*x2
		if 0 < w && w < 1:
			break
	w = sqrt(-2 * log(w)/w)
	return round(mean + deviation * x1 * w)


func sort_neighbours():
	neighbours.sort_custom(MyCustomSorter, "sort")


func sort_traders(idx = 1, resource = 0): #idx = 2 ~ buy, idx = 3 ~ sell
	if idx == 1:
		traders.sort_custom(MyCustomSorter, "sort")
	elif idx == 2:
		if resource == 0:
			traders.sort_custom(MyCustomTraderSorter, "sort_buy_food")
	elif idx == 3:
		if resource == 0:
			traders.sort_custom(MyCustomTraderSorter, "sort_sell_food")


"""Return 'start'st/nd/rd/th cheapest resource, starting from 'start' index in sorted neighbours array"""
func get_cheapest_resource(start = 0) -> Node2D:
	return neighbours[start][0]


func _draw():
	draw_circle(Vector2(0,0), radius, Color(0.55, 0, 0, 0.3))
	for resource in get_tree().get_nodes_in_group("resource"):
		var isNeighbour = false
		for i in range(neighbours.size()):
			if resource == neighbours[i][0]:
				isNeighbour = true
		if resource._resource_type != -1: # do not draw lines to null resources
			if isNeighbour:
				draw_line(Vector2(0,0), resource.position - position, Color(0, 1, 0, 1), 3.0) # green
			elif position.distance_squared_to(resource.position) < 2 * RAD_SQ:
				draw_line(Vector2(0,0), resource.position - position, Color(1, 0, 0, 1), 3.0) # red
		# BUG OX and OY are rendered partially invisible after few update calls (best depicted with zoom > 2)
	
	draw_circle(Vector2(0,0), radius * sqrt(1.9), Color(1, 1, 0, 0.04))
	for village in get_tree().get_nodes_in_group("village"): #NOTE jeśli miasto A widzi miasto B to niekoniecznie w 2 stronę
		var isTrader = false
		for i in range(traders.size()):
			if village == traders[i][0]:
				isTrader = true
		if isTrader:
			draw_line(Vector2(0,0), village.position - position, Color(1, 1, 0, 1), 3.0) # yellow
#			draw_circle(village.position - position, 50, Color(1, 1, 0, 1))
	draw_population_chart(2) # zoom parameter 


"""Called by _draw"""
func draw_population_chart(zoom: int = 1):
	var start_x  = 0
	var end_x    = 100
	var start_y  = 110
	var end_y    = 60
	draw_line(Vector2(start_x, start_y) , Vector2(end_x, start_y) , Color.white, 1.0) # OX
	draw_line(Vector2(start_x, start_y) , Vector2(start_x, end_y) , Color.white, 1.0) # OY
	for i in range(99):
		draw_line(Vector2(start_x + zoom*i, start_y - zoom*POPULATION_by_age[i]),\
		          Vector2(start_x + zoom*i + zoom*1, start_y - zoom*POPULATION_by_age[i+1]) , Color.white, 1)


"""Actualize settlement info displayed on scene, function called by update_village."""
func update_display():
	$InfoTable/values.text = append_population_info()
	$InfoTable/values.text += append_calc_workforce_info()
	$InfoTable/values.text += append_workforce_used_info()
	
	$InfoTable/values.text += str(stepify(stockpile_food, 0.1))+"\n"
	$InfoTable/values.text += str(stepify(consumption_food, 0.1))+"/s\n"
	update_cost_labels("CostLabels")
	_set_settlement_type(clamp(population_total/50, 0, 3)) # population_total/50 to dzielenie intów, więc powinno obciąć:
	# 0-49 to 0, 50-99 to 1, 100-149 to 2 i 150+ to 3


"""Display settlement info on_hover, it contains all info of update_display and some more."""
func on_hover_info():
	globals.debug.text += "\n*** " + $name.text + " ***\n"
	globals.debug.text += "population_total: " + append_population_info()
	globals.debug.text += "calculated_workforce: " + append_calc_workforce_info()
	globals.debug.text += "workforce used: " + append_workforce_used_info()
	
	globals.debug.text += "\nFood: " + append_stockpile_food_info()
	globals.debug.text += "Wood: " + str(stockpile_wood) + "\n"
	globals.debug.text += "Stone: " + str(stockpile_stone) + "\n"
	globals.debug.text += "Gold: " + str(stockpile_gold) + "\n"
	globals.debug.text += "\nHousing: " + str(housing) + "\n"
	globals.debug.text += "Housing req: " + str(housing_req_total) + "\n"
	globals.debug.text += "Need more houses: " + str(NEED_MORE_HOUSES) + "\n"
	globals.debug.text += "Need more food: " + str(NEED_MORE_FOOD) + "\n"
	globals.debug.text += "\nTrading info: " + append_trading_info()
	globals.debug.text += "\nNEARBY TRADERS\n" + traders_info() + "\n"
	globals.debug.text += "\nNEARBY RESOURCES\n" + neighbours_info() + "\n"
#	                  + " = " + str(workforce_collecting + total_workforce_transporting_this_cycle) + "\n"


"""Append_*_info functions appends numerical values connected to some village parameter to given string.""" 
func append_population_info():
	var text: String = ""
	text += str(population_total)
	if population_total_fluctuations < 0: 
		text += " (+" + str(-population_total_fluctuations)+")\n"
	else: text += " (" + str(-population_total_fluctuations)+")\n"
	return text


func append_calc_workforce_info():
	var text: String = ""
	text += str(stepify(calculated_workforce, 0.1))
	if calculated_workforce_fluctuations < 0: 
		text += " (+" + str(-stepify(calculated_workforce_fluctuations, 0.1))+")\n"
	else: text += " (" + str(-stepify(calculated_workforce_fluctuations, 0.1))+")\n"
	return text


func append_workforce_used_info():
	var text: String = ""
	if calculated_workforce != 0:
		text += str(stepify(100*((calculated_workforce - workforce)/calculated_workforce), 0.1))+"%\n"
	else: text += "ALL DEAD\n"
	return text


func append_stockpile_food_info():
	var text: String = ""
	text += str(stockpile_food)
	if stockpile_food_fluctuations < 0: 
		text += " (+" + str(-stockpile_food_fluctuations)+")\n"
	else: text += " (" + str(-stockpile_food_fluctuations)+")\n"
	return text


func append_trading_info():
	var text: String = ""
	#enum Actions {KEEPING = -1, SELLING, BUYING}
	for action in TRADING:
		if action == -1:
			text += "KEEP "
		if action == 0:
			text += "SELL "
		if action == 1:
			text += "BUY "
	
	text += "\nBuying info: "
	for i in range(3):
		text += "  " + str(BUY_PRICES[i]) + "  "
	
	text += "\nSelling info: "
	for i in range(3):
		text += "  " + str(SELL_PRICES[i]) + "  "
	text += "\n"
	
	return text