@tool
extends EditorPlugin

var debug_show_collider:bool = false

var ui_sidebar
var ui_activate_button
var brush_cursor
var vertex_preview:MultiMeshInstance3D

var edit_mode:bool:
	set(value):
		if edit_mode == value:
			return
	
		edit_mode = value
		if edit_mode:
			update_vertex_previews()
			_set_collision()
			ui_sidebar.visible = true
		else:
			vertex_preview.visible = false
			ui_sidebar.hide()
			_delete_collision()
			ui_sidebar.visible = false
			process_drawing = false
			brush_cursor.visible = false
			invert_brush = false
			reset_preview_mat()

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

var raycast_hit:bool = false
var hit_position
var hit_normal

var change_size := false
var first_change_size_pos := Vector2.ZERO
var updated_change_size_pos := Vector2.ZERO

func _handles(obj) -> bool:
	return obj is MeshInstance3D

func _make_visible(visible: bool) -> void:
	if not visible and edit_mode:
		edit_mode = false

	if ui_activate_button:
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, ui_activate_button)
		ui_activate_button.queue_free()
		ui_activate_button = null

	if visible:
		ui_activate_button = Button.new()
		ui_activate_button.text = "VPaint"
		ui_activate_button.icon = preload("res://addons/vpainter/res/icons/icon_vpainter.svg")
		ui_activate_button.toggle_mode = true
		ui_activate_button.toggled.connect(ui_activate_button_toggled_)
		add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, ui_activate_button)

func _edit(object) -> void:
	if current_mesh:
		_delete_collision()
		current_mesh = null

	current_mesh = object
	edit_mode = false
	
	if current_mesh and current_mesh.mesh is ArrayMesh:
		ui_sidebar.show_conversion(false)
	else:
		ui_sidebar.show_conversion(true)

func ui_activate_button_toggled_(toggle:bool) -> void:
	edit_mode = toggle


func _forward_3d_gui_input(camera, event) -> int:
	if not edit_mode:
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	_calculate_brush_pressure(event)
	_raycast(camera, event)
	update_closest_vertex_help_info()

	return _user_input(event)


func _physics_process(_delta):
	if not current_mesh:
		return
	
	_display_brush()

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

func _user_input(event) -> int:
	if raycast_hit:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				process_drawing = true
				_process_drawing()
			else:
				process_drawing = false
			
			return EditorPlugin.AFTER_GUI_INPUT_STOP
				
		if event is InputEventKey and event.physical_keycode == KEY_CTRL:
			if event.is_pressed():
				invert_brush = true
			else:
				invert_brush = false
			
			return EditorPlugin.AFTER_GUI_INPUT_STOP

	# prevents deselecting if click outside of object
	# it's really annoying to accidentaly paint just outside the edges of a mesh and deselect it
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# TODO: Make it so a double click escapes. Double click event desn't seem to work in editor though : (
		return EditorPlugin.AFTER_GUI_INPUT_STOP

	return EditorPlugin.AFTER_GUI_INPUT_PASS

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
		
		if not invert_brush:
			brush_cursor.material_override.set_shader_parameter("albedo", paint_color)
		else:
			brush_cursor.material_override.set_shader_parameter("albedo", paint_color_secondary)

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


func _raycast(camera:Camera3D, event:InputEvent) -> void:
	if event is InputEventMouse:
		var ray_origin = camera.project_ray_origin(camera.get_viewport().get_mouse_position())
		var ray_dir = camera.project_ray_normal(camera.get_viewport().get_mouse_position())

		var ray_distance = camera.far

		var a := get_viewport()
		var space_state =  a.world_3d.direct_space_state
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
		var undo := get_undo_redo()
		undo.create_action("Paint Vertex", UndoRedo.MERGE_ENDS)

		var undo_data = MeshDataTool.new()
		undo_data.create_from_surface(current_mesh.mesh, 0)
		undo.add_undo_method(self, "commit_paint", current_mesh,  undo_data)
		
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
		
		undo.add_do_method(self, "commit_paint", current_mesh, data)
		undo.commit_action()

func commit_paint(mesh:MeshInstance3D, data:MeshDataTool) -> void:
	mesh.mesh.clear_surfaces()
	data.commit_to_surface(mesh.mesh)
	update_vertex_previews()
	EditorInterface.mark_scene_as_unsaved()

func _displace_tool() -> void:
	var undo := get_undo_redo()
	undo.create_action("Displace Vertex", UndoRedo.MERGE_ENDS)
	
	var undo_data = MeshDataTool.new()
	undo_data.create_from_surface(current_mesh.mesh, 0)
	undo.add_undo_method(self, "commit_paint", current_mesh, undo_data)

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

	undo.add_do_method(self, "commit_paint", current_mesh, data)
	undo.commit_action()

func _blur_tool() -> void:
	pass

func _fill_tool() -> void:
	var undo := get_undo_redo()
	undo.create_action("Fill Vertex")

	var undo_data = MeshDataTool.new()
	undo_data.create_from_surface(current_mesh.mesh, 0)
	undo.add_undo_method(self, "commit_paint", current_mesh, undo_data)
	
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

	process_drawing = false
	
	undo.add_do_method(self, "commit_paint", current_mesh, data)
	undo.commit_action()


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

func update_closest_vertex_help_info():
	if not hit_position:
		return
	
	if not current_mesh.mesh is ArrayMesh:
		return

	var data = MeshDataTool.new()
	data.create_from_surface(current_mesh.mesh, 0)
	
	var closest_distance:float = INF
	var closest_vertex_index := -1

	for i in range(data.get_vertex_count()):
		var vertex = current_mesh.to_global(data.get_vertex(i))

		if vertex.distance_to(hit_position) < closest_distance:
			closest_distance = vertex.distance_to(hit_position)
			closest_vertex_index = i

	if closest_vertex_index >= 0:
		var color = data.get_vertex_color(closest_vertex_index)
		var info := "Closest Vertex:\n"
		info += "Index: %s\n" % closest_vertex_index
		info += "Color: (%s, %s, %s, %s)" % [color.r8, color.g8, color.b8, color.a8]
		ui_sidebar.set_info(info)

func update_vertex_previews() -> void:
	if not current_mesh:
		return

	var data = MeshDataTool.new()
	data.create_from_surface(current_mesh.mesh, 0)

	vertex_preview.global_transform = current_mesh.global_transform
	vertex_preview.multimesh.instance_count = data.get_vertex_count()

	for i in data.get_vertex_count():
		var t := Transform3D()
		t.origin = data.get_vertex(i)
		vertex_preview.multimesh.set_instance_transform(i, t)
		vertex_preview.multimesh.set_instance_color(i, data.get_vertex_color(i))
		
	vertex_preview.visible = true


func _set_collision() -> void:
	var temp_collision = current_mesh.get_node_or_null(str(current_mesh.name) + "_col")
	if (temp_collision == null):
		current_mesh.create_trimesh_collision()
		temp_collision = current_mesh.get_node(str(current_mesh.name) + "_col")
		temp_collision.set_collision_layer(524288)
		temp_collision.set_collision_mask(524288)
		temp_collision.owner = null	
	else:
		temp_collision.queue_free()
		current_mesh.create_trimesh_collision()
		temp_collision = current_mesh.get_node(str(current_mesh.name) + "_col")
		temp_collision.set_collision_layer(524288)
		temp_collision.set_collision_mask(524288)
		temp_collision.owner = null
	
	if !debug_show_collider:
		temp_collision.hide()

func _delete_collision() -> void:
	if !is_instance_valid(current_mesh):
		return
	var temp_collision = current_mesh.get_node_or_null(str(current_mesh.name) + "_col")
	if (temp_collision != null):
		temp_collision.queue_free()

func _make_local_copy() -> void:
	current_mesh.mesh = current_mesh.mesh.duplicate(false)


func _convert_to_mesh() -> void:
	var undo := get_undo_redo()
	undo.create_action("Convert to Mesh")
	undo.add_undo_method(self, "convert_to_mesh_undo", current_mesh.mesh)
	undo.add_do_method(self, "convert_to_mesh_do", current_mesh.mesh)
	undo.commit_action()

func _gridify(subdivisions:Vector2i) -> void:
	var undo := get_undo_redo()
	undo.create_action("Gridify Mesh")
	
	var old_mesh_data := MeshDataTool.new()
	old_mesh_data.create_from_surface(current_mesh.mesh, 0)
	undo.add_undo_method(self, "commit_paint", current_mesh, old_mesh_data)
	
	
	var aabb := current_mesh.mesh.get_aabb()
	var aabb_size := [aabb.size.x, aabb.size.y, aabb.size.z]
	aabb_size.sort()
	
	var a := QuadMesh.new()
	a.orientation = VPainterMeshTools.get_facing_orientation(aabb.size)
	
	a.size.x = aabb_size[2]
	a.size.y = aabb_size[1]

	a.subdivide_depth = subdivisions.x
	a.subdivide_width = subdivisions.y

	var surface_tool := SurfaceTool.new()
	surface_tool.create_from(a, 0)
	
	var new_mesh := surface_tool.commit()
	var new_mesh_data := MeshDataTool.new()
	new_mesh_data.create_from_surface(new_mesh, 0)
	
	for i in new_mesh_data.get_vertex_count():
		var f = VPainterMeshTools.find_closet_3_points(current_mesh.mesh, new_mesh_data.get_vertex(i))
		if f:
			var verticies:Array[Vector3] = [
				old_mesh_data.get_vertex(f[0]), 
				old_mesh_data.get_vertex(f[1]),
				old_mesh_data.get_vertex(f[2])
				]
			
			var colors:Array[Color] = [
				old_mesh_data.get_vertex_color(f[0]), 
				old_mesh_data.get_vertex_color(f[1]),
				old_mesh_data.get_vertex_color(f[2])
				]
			
			var color = VPainterMeshTools.get_interpolated_color(new_mesh_data.get_vertex(i), verticies, colors)
			
			new_mesh_data.set_vertex_color(i, color)
		else:
			print("no face found")

	undo.add_do_method(self, "commit_paint", current_mesh, new_mesh_data)
	undo.commit_action()
	

func convert_to_mesh_do(old_mesh:Mesh) -> void:
	var surface_tool := SurfaceTool.new()
	surface_tool.set_color(Color.BLACK)
	surface_tool.create_from(old_mesh.duplicate(false), 0)
	var array_mesh := surface_tool.commit()
	current_mesh.mesh = array_mesh
	await(RenderingServer.frame_post_draw)
	ui_sidebar.show_conversion(false)

func convert_to_mesh_undo(old_mesh:Mesh) -> void:
	current_mesh.mesh = old_mesh
	await(RenderingServer.frame_post_draw)
	ui_sidebar.show_conversion(true)

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
	
	#LOAD BRUSH:
	brush_cursor = preload("res://addons/vpainter/res/brush_cursor/BrushCursor.tscn").instantiate()
	brush_cursor.visible = false
	add_child(brush_cursor)
	
	#LOAD VERTEX PREVIEW
	vertex_preview = preload("res://addons/vpainter/res/vpainter_vertex_probes.tscn").instantiate()
	vertex_preview.visible = false
	add_child(vertex_preview)

func _exit_tree() -> void:
	#REMOVE THE SIDEBAR:
	remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_SIDE_LEFT, ui_sidebar)
	if ui_sidebar:
		ui_sidebar.free()
	#REMOVE THE EDITOR BUTTON:
	remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, ui_activate_button)
	if ui_activate_button:
		ui_activate_button.free()
