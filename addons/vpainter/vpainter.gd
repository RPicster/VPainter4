@tool
extends EditorPlugin

var debug_show_collider:bool = false

var ui_sidebar
var ui_activate_button
var brush_cursor

var edit_mode:bool:
	set(value):
		edit_mode = value
		if edit_mode:
			_set_collision()
		else:
			ui_sidebar.hide()
			_delete_collision()

var paint_color:Color
var paint_color_secondary:Color
var original_mat_override:Material
var preview_active := false

enum {MIX, ADD, SUBTRACT, MULTIPLY, DIVIDE}
var blend_mode = MIX

enum {STANDART, INFLATE, MOVE, SMOOTH}
var sculpt_mode = STANDART

var current_tool = "_paint_tool"

var invert_brush = false

var pressure_opacity:bool = false
var pressure_size:bool = false
var brush_pressure:float = 0.0
var process_drawing:bool = false

var brush_size:float = 1
var calculated_size:float = 1.0

var brush_opacity:float = 0.5
var calculated_opacity:float = 0.0

var brush_hardness:float = 0.5
var brush_spacing:float = 0.1
var brush_random:float = 0.0

var current_mesh:MeshInstance3D
var editable_object:bool = false

var raycast_hit:bool = false
var hit_position
var hit_normal


func _handles(obj) -> bool:
	return editable_object and obj is MeshInstance3D


func _forward_3d_gui_input(camera, event) -> int:
	if !edit_mode:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	_display_brush()
	_calculate_brush_pressure(event)
	_raycast(camera, event)
	
	if raycast_hit:
		return int(_user_input(event)) #the returned value blocks or unblocks the default input from godot
	return EditorPlugin.AFTER_GUI_INPUT_PASS


func _physics_process(_delta):
	if !edit_mode:
		return
	if Input.is_physical_key_pressed(KEY_S):
		if not change_size:
			first_change_size_pos = get_viewport().get_mouse_position()
			change_size = true
		updated_change_size_pos = get_viewport().get_mouse_position()
		var dist : Vector2 = (updated_change_size_pos-first_change_size_pos)*0.02
		ui_sidebar._set_brush_size(brush_size+dist.x)
		ui_sidebar._set_brush_opacity(brush_opacity-dist.y)
		first_change_size_pos = get_viewport().get_mouse_position()
	elif change_size:
		change_size = false


var change_size := false
var first_change_size_pos := Vector2.ZERO
var updated_change_size_pos := Vector2.ZERO
func _user_input(event) -> bool:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			process_drawing = true
			_process_drawing()
			return true
		else:
			process_drawing = false
			_set_collision()
			return false
	
	if event is InputEventKey and event.physical_keycode == KEY_CTRL:
		if event.is_pressed():
			invert_brush = true
			return false
		else:
			invert_brush = false
			return false
	else:
		return false


func _process_drawing():
	while process_drawing:
		call(current_tool)
		await get_tree().create_timer(brush_spacing).timeout

func _display_brush() -> void:
	if raycast_hit:
		brush_cursor.visible = true
		brush_cursor.position = hit_position
		brush_cursor.scale = Vector3.ONE * calculated_size
		var draw_mod = 0.6 if process_drawing else 0.0
		brush_cursor.transparency = min(remap(brush_opacity, 0.0, 1.0, 0.9, 0.3)+draw_mod, 0.9)
	else:
		brush_cursor.visible = false

func _calculate_brush_pressure(event) -> void:
	if event is InputEventMouseMotion:
		brush_pressure = event.pressure
		if pressure_size:
			calculated_size = (brush_size * brush_pressure)/2
		else:
			calculated_size = brush_size

		if pressure_opacity:
			calculated_opacity = brush_opacity * brush_pressure
		else:
			calculated_opacity = brush_opacity

func _raycast(camera:Node, event:InputEvent) -> void:
	if event is InputEventMouse:
		#RAYCAST FROM CAMERA:
		var ray_origin = camera.project_ray_origin(camera.get_viewport().get_mouse_position())
		var ray_dir = camera.project_ray_normal(camera.get_viewport().get_mouse_position())
		var ray_distance = camera.far

		var space_state =  get_viewport().world_3d.direct_space_state
		var p = PhysicsRayQueryParameters3D.new()
		p.from = ray_origin
		p.to = ray_origin + ray_dir * ray_distance
		p.collision_mask = 524288
		var hit = space_state.intersect_ray(p)
		#IF RAYCAST HITS A DRAWABLE SURFACE:
		if hit.size() == 0:
			raycast_hit = false
			return
		if hit:
			raycast_hit = true
			hit_position = hit.position
			hit_normal = hit.normal

func _paint_tool() -> void:
		var data = MeshDataTool.new()
		data.create_from_surface(current_mesh.mesh, 0)
		
		var use_color : Color = paint_color if not invert_brush else paint_color_secondary
		
		for i in range(data.get_vertex_count()):
			var vertex = current_mesh.to_global(data.get_vertex(i))
			var vertex_distance:float = vertex.distance_to(hit_position)
			
			if vertex_distance < calculated_size/2:
				var linear_distance = 1 - (vertex_distance / (calculated_size/2))
				var calculated_hardness = linear_distance * brush_hardness
				var power = calculated_opacity * calculated_hardness * lerp(1.0, randf(), brush_random)
				match blend_mode:
					MIX:
						data.set_vertex_color(i, data.get_vertex_color(i).lerp(use_color, power))
					ADD:
						data.set_vertex_color(i, data.get_vertex_color(i).lerp(data.get_vertex_color(i) + use_color, power))
					SUBTRACT:
						data.set_vertex_color(i, data.get_vertex_color(i).lerp(data.get_vertex_color(i) - use_color, power))
					MULTIPLY:
						data.set_vertex_color(i, data.get_vertex_color(i).lerp(data.get_vertex_color(i) * use_color, power))
					DIVIDE:
						data.set_vertex_color(i, data.get_vertex_color(i).lerp(data.get_vertex_color(i) / use_color, power))

		current_mesh.mesh.clear_surfaces()
		data.commit_to_surface(current_mesh.mesh)

func _displace_tool() -> void:
		var data = MeshDataTool.new()
		data.create_from_surface(current_mesh.mesh, 0)

		for i in range(data.get_vertex_count()):
			var vertex = current_mesh.to_global(data.get_vertex(i))
			var vertex_distance:float = vertex.distance_to(hit_position)

			if vertex_distance < calculated_size/2:
				var linear_distance = 1 - (vertex_distance / (calculated_size/2))
				var calculated_hardness = linear_distance * brush_hardness
				var power = hit_normal * calculated_opacity * calculated_hardness * 0.3 * lerp(1.0, randf(), brush_random)

				if !invert_brush:
					data.set_vertex(i, data.get_vertex(i) + power)
				else:
					data.set_vertex(i, data.get_vertex(i) - power)

		current_mesh.mesh.clear_surfaces()
		data.commit_to_surface(current_mesh.mesh)

func _blur_tool() -> void:
	pass

func _fill_tool() -> void:
	var data = MeshDataTool.new()
	data.create_from_surface(current_mesh.mesh, 0)
	
	var use_color : Color = paint_color if not invert_brush else paint_color_secondary
	
	for i in range(data.get_vertex_count()):
		var vertex = data.get_vertex(i)
		
		match blend_mode:
			MIX:
				data.set_vertex_color(i, data.get_vertex_color(i).lerp(use_color, brush_opacity * lerp(1.0, randf(), brush_random)))
			ADD:
				data.set_vertex_color(i, data.get_vertex_color(i).lerp(data.get_vertex_color(i) + use_color, brush_opacity * lerp(1.0, randf(), brush_random)))
			SUBTRACT:
				data.set_vertex_color(i, data.get_vertex_color(i).lerp(data.get_vertex_color(i) - use_color, brush_opacity * lerp(1.0, randf(), brush_random)))
			MULTIPLY:
				data.set_vertex_color(i, data.get_vertex_color(i).lerp(data.get_vertex_color(i) * use_color, brush_opacity * lerp(1.0, randf(), brush_random)))
			DIVIDE:
				data.set_vertex_color(i, data.get_vertex_color(i).lerp(data.get_vertex_color(i) / use_color, brush_opacity * lerp(1.0, randf(), brush_random)))

	current_mesh.mesh.clear_surfaces()
	data.commit_to_surface(current_mesh.mesh)
	process_drawing = false


func _sample_tool() -> void:
	var data = MeshDataTool.new()
	data.create_from_surface(current_mesh.mesh, 0)
	
	var closest_distance:float = INF
	var closest_vertex_index:int

	for i in range(data.get_vertex_count()):
		var vertex = current_mesh.to_global(data.get_vertex(i))

		if vertex.distance_to(hit_position) < closest_distance:
			closest_distance = vertex.distance_to(hit_position)
			closest_vertex_index = i
	
	var picked_color = data.get_vertex_color(closest_vertex_index)
	paint_color = Color(picked_color.r, picked_color.g, picked_color.b, 1)
	ui_sidebar._set_paint_color(paint_color)
	
	current_mesh.mesh.clear_surfaces()
	data.commit_to_surface(current_mesh.mesh)

func _set_collision() -> void:
	var temp_collision = current_mesh.get_node_or_null(str(current_mesh.name) + "_col")
	if (temp_collision == null):
		current_mesh.create_trimesh_collision()
		temp_collision = current_mesh.get_node(str(current_mesh.name) + "_col")
		temp_collision.set_collision_layer(524288)
		temp_collision.set_collision_mask(524288)
	else:
		temp_collision.free()
		current_mesh.create_trimesh_collision()
		temp_collision = current_mesh.get_node(str(current_mesh.name) + "_col")
		temp_collision.set_collision_layer(524288)
		temp_collision.set_collision_mask(524288)
	
	if !debug_show_collider:
		temp_collision.hide()

func _delete_collision() -> void:
	if !is_instance_valid(current_mesh):return
	var temp_collision = current_mesh.get_node_or_null(str(current_mesh.name) + "_col")
	if (temp_collision != null):
		temp_collision.free()

func _set_edit_mode(value) -> void:
	edit_mode = value
	if !current_mesh:
		return
		if (!current_mesh.mesh):
			return

	if edit_mode:
		_set_collision()
	else:
		ui_sidebar.hide()
		_delete_collision()


func _make_local_copy() -> void:
	var surface_tool := SurfaceTool.new()
	surface_tool.create_from(current_mesh.mesh.duplicate(false), 0)
	var array_mesh := surface_tool.commit()
	surface_tool.generate_tangents()
	current_mesh.mesh = array_mesh


func _convert_to_mesh() -> void:
	var surface_tool := SurfaceTool.new()
	surface_tool.set_color(Color.BLACK)
	surface_tool.create_from(current_mesh.mesh.duplicate(false), 0)
	var array_mesh := surface_tool.commit()
	current_mesh.mesh = array_mesh
	await(RenderingServer.frame_post_draw)
	ui_sidebar.show_conversion(false)


func _selection_changed() -> void:
	ui_activate_button._set_ui_sidebar(false)
	
	var selection = EditorInterface.get_selection().get_selected_nodes()

	if selection.size() == 1 and selection[0] is MeshInstance3D:
		current_mesh = selection[0]
		if current_mesh.mesh == null:
			ui_activate_button._set_ui_sidebar(false)
			ui_activate_button._hide()
			editable_object = false
		else:
			if current_mesh.mesh is ArrayMesh:
				ui_sidebar.show_conversion(false)
				editable_object = true
			else:
				ui_sidebar.show_conversion(true)
				editable_object = false
			ui_activate_button._show()
	else:
		reset_preview_mat()
		current_mesh = null
		editable_object = false
		ui_activate_button._set_ui_sidebar(false) #HIDE THE SIDEBAR
		ui_activate_button._hide()


func set_preview_mat():
	if preview_active:
		reset_preview_mat()
		return
	preview_active = true
	original_mat_override = current_mesh.material_override
	current_mesh.material_override = preload("res://addons/vpainter/additional_resources/vertex_preview_material.material")


func reset_preview_mat():
	if preview_active:
		preview_active = false
		current_mesh.material_override = original_mat_override
		original_mat_override = null


func _enter_tree():
	#SETUP THE SIDEBAR:
	ui_sidebar = load("res://addons/vpainter/vpainter_ui.tscn").instantiate()
	ui_sidebar.vpainter = self
	ui_sidebar.hide()
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_SIDE_LEFT, ui_sidebar)
	
	#SETUP THE EDITOR BUTTON:
	ui_activate_button = load("res://addons/vpainter/vpainter_activate_button.tscn").instantiate()
	ui_activate_button.hide()
	ui_activate_button.vpainter = self
	ui_activate_button.ui_sidebar = ui_sidebar
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, ui_activate_button)
	
	#SELECTION SIGNAL:
	EditorInterface.get_selection().selection_changed.connect(_selection_changed)
	
	#LOAD BRUSH:
	brush_cursor = preload("res://addons/vpainter/res/brush_cursor/BrushCursor.tscn").instantiate()
	brush_cursor.visible = false
	add_child(brush_cursor)


func _exit_tree() -> void:
	#REMOVE THE SIDEBAR:
	remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_SIDE_LEFT, ui_sidebar)
	if ui_sidebar:
		ui_sidebar.free()
	#REMOVE THE EDITOR BUTTON:
	remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, ui_activate_button)
	if ui_activate_button:
		ui_activate_button.free()
