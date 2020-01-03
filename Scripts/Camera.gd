extends Camera2D

onready var previous_mouse_possition = get_global_mouse_position()
onready var previous_position = position
onready var target_position = position
onready var target_zoom = Vector2(1.0, 1.0)

const zoom_levels = [0.25, 0.5, 0.75, 1, 1.25, 1.5, 2, 3, 4]
var current_zoom_index = 3
var current_zoom_level = zoom_levels[current_zoom_index]

func _process(delta):
	globals.debug.text += "MOUSE POSITION (Camera.gd)\nGlobal:" + str(get_global_mouse_position().floor())
	globals.debug.text += "\nLocal:" + str(get_local_mouse_position().floor())
	globals.debug.text += "\nViewport:" + str(get_viewport().get_mouse_position().floor()) + "\n"
	globals.debug.text += "\nCAMERA ZOOM: %4.2f" % zoom.x + "\n"
	if globals.selected_node != null and globals.selected_node.has_method("on_hover_info"):
		globals.selected_node.on_hover_info()

func _physics_process(delta):
	position = lerp(position, target_position, 20 * delta)
	zoom     = lerp(zoom, target_zoom, 20 * delta)
	
func _input(event):
	""" Mouse picking """

	if event is InputEventMouseMotion:
		handle_mouse_motion_event(event)

	if event is InputEventMouseButton:
		handle_mouse_button_event(event)

func handle_mouse_motion_event(event):
	if globals.mouse_button_pressed:
		if globals.selected_node: #something is selected
			globals.selected_node.position = get_global_mouse_position().floor()
			for village in get_tree().get_nodes_in_group("village"):
				village.detect_neighbours()
				village.sort_neighbours()
				village.detect_traders()
				village.sort_traders()
				village.update()
		else: #nothing selected -> drag camera
			target_position = previous_position + previous_mouse_possition - get_local_mouse_position()
#			position = lerp(position, target_camera_position, 0.5)
	else: #camera hoverig
#		globals.selected_node = null
		get_object_near_mouse()

func handle_mouse_button_event(event):
	if event.pressed: 
		if event.button_index == BUTTON_WHEEL_UP:
			if abs(zoom_levels[current_zoom_index] - zoom.x) < 0.1 * target_zoom.x && current_zoom_index > 0:
				current_zoom_index -= 1
				target_zoom = Vector2(zoom_levels[current_zoom_index],zoom_levels[current_zoom_index])
#				target_zoom -= (globals.ZOOM_SPEED + target_zoom * 0.1)
				target_position += get_local_mouse_position() * 0.4
				
		elif event.button_index == BUTTON_WHEEL_DOWN:
			if abs(zoom_levels[current_zoom_index] - zoom.x) < 0.1 * target_zoom.x && current_zoom_index < zoom_levels.size()-1:
				current_zoom_index += 1
				target_zoom = Vector2(zoom_levels[current_zoom_index],zoom_levels[current_zoom_index])
#				target_zoom += (globals.ZOOM_SPEED + target_zoom * 0.1)
				target_position -= get_local_mouse_position() * 0.4
			
		else: #button pressed -> check if got something selected
			globals.mouse_button_pressed = true
			previous_mouse_possition = get_local_mouse_position()
			previous_position = position

#			get_object_near_mouse()
	else: # button released
		globals.mouse_button_pressed = false
		globals.selected_node = null
			
func get_object_near_mouse():
	var is_hovering = false
	for node in get_tree().get_nodes_in_group("selectable"):
		if get_global_mouse_position().distance_to(node.position) < globals.SELECTION_RANGE:
			is_hovering = true
			globals.selected_node = node
			node.sprite.material.set("shader_param/width", 1.0)
	if !is_hovering and globals.selected_node :
		globals.selected_node.sprite.material.set("shader_param/width", 0.0)
		globals.selected_node.update()
		globals.selected_node = null
