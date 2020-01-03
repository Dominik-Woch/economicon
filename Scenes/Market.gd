extends Node2D

var done_trading := false

var production  := [0.0, 0.0, 0.0]
var production_base   := [500.0, 100.0, 100.0]
var production_drift  := [0.0, 0.0, 0.0]

var product_base_cost  := [1.0, 4.0, 6.0]

var supply      := [0.0, 0.0, 0.0]
var demand      := [200.0, 100.0, 100.0]
var surplus     := [0.0, 0.0, 0.0]
var supply_value := [0.0, 0.0, 0.0]
var demand_value := [0.0, 0.0, 0.0]
#var value_bases  := [10.0, 10.0, 10.0]


var prod_hist   := [PoolRealArray(),PoolRealArray(),PoolRealArray()]
var value_hist  := [PoolRealArray(),PoolRealArray(),PoolRealArray()]
var prod_avg    := [0.0, 0.0, 0.0]
var value_avg   := [0.0, 0.0, 0.0]
var prod_avg_prev   := [0.0, 0.0, 0.0]
var value_avg_prev  := [0.0, 0.0, 0.0]

var goods_names = [ "FOOD", "WOOD", "STONE" ]
var goods_color = [ Color(0.0, 1.0, 0.0 ,1.0), Color(0.6, 0.6, 0.0, 1.0), Color(0.5, 0.5, 0.5, 1.0) ]

var tic_timer       := 0.0
var tic_duration    := 0.1
var hist_step_timer := 0
var hist_step       := 0

func _ready():
	randomize()
	for i in range(3):
		production_base[i] += (randi() % 50) - 25
	init_hist_values()
	
func init_hist_values():
	var clear_array = PoolRealArray([0])
	clear_array.resize(100)
	for i in range(3):
		prod_hist[i] = clear_array
		value_hist[i]= clear_array
		for k in range(100):
			prod_hist[i][k] = production_base[i]
			value_hist[i][k] = demand_value[i]
	
func _physics_process(delta):
	tic_timer += delta
	if tic_timer >= tic_duration:
		tic_timer = 0.0
		hist_step_timer += 1
		process_developement()
		if hist_step_timer > 10:
			hist_step_timer = 0
			hist_step = (hist_step + 1) % 100
			store_data()
#			for i in range(3):
#				var prod_range = production_base[i]*0.05-production_drift[i]*0.1+1
#				production_drift_target[i] = rand_range( -prod_range, prod_range) + rand_range( -prod_range, prod_range)

	update()
	
func store_data():
	for i in range(3):
		prod_hist[i][hist_step]  = production[i]
		value_hist[i][hist_step] = demand_value[i]
			
func process_developement():
	for i in range(3):
		production[i] = max(1,(production_base[i] + production_drift[i]))
		supply[i]  = production[i] #+ surplus[i]
		
		supply_value[i] = (supply_price( product_base_cost[i], production[i]/1000.0) * production[i] + supply_value[i] * surplus[i]) / supply[i]
		demand_value[i] = demand_price( product_base_cost[i], production[i]/1000.0)

#		surplus[i] = production[i] - demand[i]

func supply_price( base_price:float, supply_quantity:float ) -> float:
	#Price = base_price + slope * supply_quantity
	return base_price + supply_curve( supply_quantity )
	
func supply_curve( x:float )->float:
	return (exp(x)-1) * 0.581977
	
	
func demand_price( base_price:float, supply_quantity:float ) -> float:
	#base_price - all factors affecting price other than price (e.g. income, fashion)
	return base_price - demand_curve( supply_quantity )
	
func demand_curve( x:float )->float:
	return (exp(-x+1)-1) * 0.581977
	
#func curve1( x:float )->float:
#	return x / (1 + abs( x ))
#
#func curve2( x:float )->float:
#	return x * x * x
	
func _draw():
	$Goods.text = ""
	$Name.text  = ""
	for i in range(3):
		$Goods.text += "%8.2f %8.2f" % [supply[i], surplus[i]]
		$Goods.text += "  ( %8.2f / %8.2f )" % [production[i],demand[i]]
		$Goods.text += "  value: %2.2f / %2.2f )" % [demand_value[i],supply_value[i]] + "$\n"
		$Name.text += goods_names[i] + ":\n"
#	draw_chart(prod_hist, Vector2(0,330), Vector2(200,-260))
#	draw_chart(value_hist, Vector2(210,330), Vector2(200,-60))
	draw_test_curve(Vector2(0,130), Vector2(100,-100))
	
func draw_chart(data, start = Vector2(0,130), size  = Vector2(200,-60)):
	draw_line(start , start + Vector2(size.x, 0) , Color.white, 2.0) # OX
	draw_line(start , start + Vector2(0, size.y) , Color.white, 2.0) # OY
	draw_line(Vector2(start.x + hist_step*2, start.y) , Vector2(start.x + hist_step*2, start.y+size.y) , Color(1,1,1,0.5), 1.0)
	for i in range(3):
		for k in range(99):
			draw_line(Vector2(start.x + k*2 , start.y - i*10 - data[i][k] ),\
			          Vector2(start.x + (k+1)*2 , start.y - i*10 - data[i][k+1] ), goods_color[i], 2.0)
func draw_test_curve(start = Vector2(0,130), size  = Vector2(200,-60)):
	draw_line(start , start + Vector2(size.x, 0) , Color.white, 2.0) # OX
	draw_line(start , start + Vector2(0, size.y) , Color.white, 2.0) # OY
	for i in range(10):
		draw_line(Vector2(start.x + i*10     , start.y - supply_curve(i    /10.0)*100),\
			      Vector2(start.x + (i+1)*10 , start.y - supply_curve((i+1)/10.0)*100 ), Color.white, 2.0)
		draw_line(Vector2(start.x + i*10     , start.y - demand_curve(i    /10.0)*100),\
			      Vector2(start.x + (i+1)*10 , start.y - demand_curve((i+1)/10.0)*100 ), Color.red, 2.0)
	draw_circle(Vector2( start.x + production[0]/10.0, start.y - supply_curve(production[0]/1000.0)*100), 3,Color.gray)
	draw_circle(Vector2( start.x + demand[0]/10.0, start.y - demand_curve(demand[0]/1000.0)*100), 3,Color.rebeccapurple)