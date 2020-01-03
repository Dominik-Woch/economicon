extends Node2D
class_name Dwelling, "res://Sprites/Farm/House_Mini.png"


enum SettlementType {NO_SETTLEMENT = -1, ABANDONED, SETTLEMENT, VILLAGE, TOWN}
var SettlementName = ["ABANDONED", "SETTLEMENT", "VILLAGE", "TOWN"]
var settlement_size = SettlementType.SETTLEMENT
var SettlementSprites = ["res://Sprites/Town/Church_5_2.png",
                       "res://Sprites/Town/Church_3.png",
                       "res://Sprites/Town/Church_5_1.png",
                       "res://Sprites/Town/Church_1.png"]


export(float) var stockpile_food: float  = 0.0
export(float) var stockpile_wood: float  = 0.0
export(float) var stockpile_stone: float = 0.0
export(float) var stockpile_gold: float  = 0.0
export(int) var population_total: int    = 20
export(int) var radius: int              = 300
#pomysł: max stockpile, magazyn na surowce i rozbudowa magazynu

#var population_transporting: int = 0 # local for transport_resources func

var housing_req_total: float                         = 0.0
var workforce_collecting: float                      = 0.0
var calculated_workforce: float                      = 0.0
var previous_calculated_workforce: float             = 0.0
var calculated_workforce_fluctuations: float         = 0.0
var workforce_needed_for_transport_this_cycle: float = 0.0
var workforce_needed_for_transport_next_cycle: float = 0.0
var workforce_reserved_for_transport: float          = 0.0
var total_workforce_transporting_this_cycle: float   = 0.0
var consumption_food: float                          = 0.0
var cycle: float                                     = 0.0
var foodreq: float                                   = 0.0
var workforce: float                                 = 0.0
var previous_stockpile_food: float                   = 0.0
var previous_stockpile_wood: float                   = 0.0
var previous_stockpile_stone: float                  = 0.0
var stockpile_food_fluctuations: float               = 0.0
var stockpile_wood_fluctuations: float               = 0.0
var stockpile_stone_fluctuations: float              = 0.0
var previous_population_total: int                   = 0
var population_total_fluctuations: int               = 0
var population_idle: int                             = 0
var population_collecting: int                       = 0#out
var population_needed_for_transport_this_cycle: int  = 0#out
var population_needed_for_transport_next_cycle: int  = 0#out
var population_reserved_for_transport: int           = 0#out
var total_population_transporting_this_cycle: int    = 0#out

# Each array holds specific data per age range (from 1 to 100 years old)
var POPULATION_by_age: Array           = []
var POPULATION_food_req: Array         = []
var POPULATION_work_eff: Array         = []
var POPULATION_death_rate: Array       = []
var POPULATION_male_ratio: Array       = []

var POPULATION_birth_rate: Array       = [] 
var population_birth_multiplier: float = 1.0

var POPULATION_housing_req: Array      = []
var housing: float                     = 10.0
