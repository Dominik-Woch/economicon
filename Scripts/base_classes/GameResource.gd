extends Node2D
class_name GameResource, "res://Sprites/Rocks/Gray_Rock_Mini.png"


enum ResourceType {NO_RESOURCE = -1, BERRIES, GRAIN, WOOD, STONE}
var ResourceExcavCost: Array = [3.0, 1.0, 1.5, 2.0]
var ResourceName: Array      = ["Berries", "Food", "Wood", "Stone"]
var ResourceSprites: Array   = ["res://Sprites/Plants/Yew_Tree.png",
                                "res://Sprites/Plants/Wheat.png",
                                "res://Sprites/Farm/Tree_2_Side.png",
                                "res://Sprites/Rocks/Gray_Rock.png"]


export(float) var available: float             = 10.0
export(float) var harvestable_per_cycle: float = 1.0
export(float) var harvest_cost_max: float      = 10.0
export(float) var auto_harvest: float          = 0.0
export(float) var regenerates_per_cycle: float = 0.0
#export(float) var stockpile_max: float         = 10.0
#export(float) var stockpile: float             = 1.0
export(float) var workforce_capacity: float    = 1.0
#export(int) var worker_capacity: int           = 1


var cycle: float                   = 0.0 
var workforce_total: float         = 0.0
var available_fluctuations: float  = 0.0
var previous_available: float      = 0.0
#var stockpile_fluctuations: float = 0.0
#var previous_stockpile: float     = 0.0
#var workers_total: int            = 0