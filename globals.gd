extends Node
"""
Globally Visible Singleton
"""


const SELECTION_RANGE          = 20
const ZOOM_SPEED               = Vector2(0.02, 0.02)


var debug: Label 


var mouse_button_pressed: bool = false
var selected_node: Node        = null