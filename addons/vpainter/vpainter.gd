tool
extends EditorPlugin

var ui_sidebar
var ui_activate_button

var paint_mode:bool setget _set_paint_mode
var paint_color:Color

enum {MIX, ADD, SUBTRACT, MULTIPLY, DIVIDE}
var blend_mode = MIX

enum {SELECT, PAINT, BLUR, FILL}
var current_tool = PAINT

var brush_size:float = 1
var brush_opacity:float = 1.0
var brush_hardness:float = 1.0
var brush_spacing:float = 0.1

var input_material:Material
var preview_material:Material


var process_drawing = false
var hit_position
var hit_normal

var current_mesh:MeshInstance

func handles(obj):
	#GET SELECTION AND IF IT'S A MESH INSTANCE SET IT AS THE MESH TO PAINT ON:
	if obj is MeshInstance:
		#IF SELECTION IS DIFFERENT FROM LAST SELECTION:
		if current_mesh != obj:
			ui_activate_button._set_ui_sidebar(false)

		current_mesh = obj

		#IF SELECTION HAS NO MESH RESOURCE:
		if (current_mesh.mesh == null):
			ui_activate_button._set_ui_sidebar(false)
			ui_activate_button._hide()
			return false


		ui_activate_button._show()
		_setup_material()
		return true
	else:
		ui_activate_button._hide()
		return false

func forward_spatial_gui_input(camera, event):
	if !paint_mode:
		return

	if event is InputEventMouse:
		_raycast(camera, event)
		#print("event")
	
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT and event.is_pressed(): 
			process_drawing = true
			match current_tool:
				PAINT:
					_paint()
					return true
				BLUR:
					return true
				FILL:
					_fill_object()
					return true
				SELECT:
					return false #ENABLE SELECTION
		else:
			process_drawing = false

func _paint():
	while process_drawing:
		var data = MeshDataTool.new()
		data.create_from_surface(current_mesh.mesh, 0)
	
		for i in range(data.get_vertex_count()):
			var vertex = data.get_vertex(i) + current_mesh.translation

			if vertex.distance_to(hit_position) < brush_size/2:
			#TODO:
				#brush hardness:
				var vertex_proximity = vertex.distance_to(hit_position)/(brush_size/2)
				var calculated_hardness = ((1 + brush_hardness) - vertex_proximity)
				
				match blend_mode:
					MIX:
						data.set_vertex_color(i, data.get_vertex_color(i).linear_interpolate(paint_color, brush_opacity * calculated_hardness))
					ADD:
						data.set_vertex_color(i, data.get_vertex_color(i).linear_interpolate(data.get_vertex_color(i) + paint_color, brush_opacity * calculated_hardness))
					SUBTRACT:
						data.set_vertex_color(i, data.get_vertex_color(i).linear_interpolate(data.get_vertex_color(i) - paint_color, brush_opacity * calculated_hardness))
					MULTIPLY:
						data.set_vertex_color(i, data.get_vertex_color(i).linear_interpolate(data.get_vertex_color(i) * paint_color, brush_opacity * calculated_hardness))
					DIVIDE:
						data.set_vertex_color(i, data.get_vertex_color(i).linear_interpolate(data.get_vertex_color(i) / paint_color, brush_opacity * calculated_hardness))

		current_mesh.mesh.surface_remove(0)
		data.commit_to_surface(current_mesh.mesh)
		yield(get_tree().create_timer(brush_spacing), "timeout")

func _fill_object():
	var data = MeshDataTool.new()
	data.create_from_surface(current_mesh.mesh, 0)

	for i in range(data.get_vertex_count()):
		var vertex = data.get_vertex(i)
		data.set_vertex_color(i, data.get_vertex_color(i).linear_interpolate(paint_color, brush_opacity))

	current_mesh.mesh.surface_remove(0)
	data.commit_to_surface(current_mesh.mesh)

func _raycast(camera:Camera, event:InputEvent):
	#RAYCAST FROM CAMERA:
	var ray_origin = camera.project_ray_origin(event.position)
	var ray_dir = camera.project_ray_normal(event.position)
	var ray_distance = camera.far

	var space_state =  get_viewport().world.direct_space_state
	var hit = space_state.intersect_ray(ray_origin, ray_origin + ray_dir * ray_distance, [] , 1)
	#IF RAYCAST HITS A DRAWABLE SURFACE:
	if!hit:
		return
	if hit:
		hit_position = hit.position
		hit_normal = hit.normal

func _set_paint_mode(value):
	paint_mode = value
	#Generate temporary collision for vertex painting:
	if !current_mesh:
		return
		if (!current_mesh.mesh):
			return

	if paint_mode:
		current_mesh.create_trimesh_collision()
		var temp_collision = current_mesh.get_node_or_null(current_mesh.name + "_col")
		if (temp_collision != null):
			temp_collision.hide()
	else:
		ui_sidebar.hide()
	#Delete the temporary collision:
		var temp_collision = current_mesh.get_node_or_null(current_mesh.name + "_col")
		if (temp_collision != null):
			temp_collision.free()

#MAKE LOCAL COPY OF THE MESH:
func _make_local_copy():
	print("works?")
	current_mesh.mesh = current_mesh.mesh.duplicate(false)

#INPUT MATERIAL:
func _load_input_material():
	if (!current_mesh.mesh):
		return
	if current_mesh.get_surface_material(0):
		input_material = current_mesh.get_surface_material(0)

func _set_input_material():
	if !current_mesh:
		return

	if (!current_mesh.mesh):
		return

	if input_material:
		current_mesh.set_surface_material(0, input_material)
	else:
		current_mesh.set_surface_material(0, null)


#PREVIEW MATERIAL:

func _load_preview_material():
	preview_material = load("res://addons/vpainter/materials/mtl_vertex_color.tres")

func _setup_material():
	#CHECK IF THERE IS A MESH INSTANCE NODE:
	if !current_mesh:
		return
	#CHECK IF THE MESH INSTANCE NODE HAS A MESH RESOURCE:
	if (!current_mesh.mesh):
		return

	#IF THE MESH HAS NO MATERIAL:
	if (!current_mesh.get_surface_material(0)):
		input_material = null #RECORD THAT THE MESH HAS NO MATERIAL.
	#IF THE OBJECT HAS A MATERIAL:
	else:					  #RECORD THE MATERIAL AS INPUT MATERIAL.
		input_material = current_mesh.get_surface_material(0)

func _set_preview_material():
	#APPLY THE PREVIEW MATERIAL.
	current_mesh.set_surface_material(0, preview_material)

func _preview_r(value:bool):
	preview_material.set_shader_param("show_r", value)

func _preview_g(value:bool):
	preview_material.set_shader_param("show_g", value)

func _preview_b(value:bool):
	preview_material.set_shader_param("show_b", value)


#LOAD AND UNLOAD ADDON:
func _enter_tree():
	#LOAD PREVIEW MATERIAL:
	_load_preview_material()
	#SETUP THE SIDEBAR:
	ui_sidebar = preload("res://addons/vpainter/vpainter_ui.tscn").instance()
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_SIDE_LEFT, ui_sidebar)
	ui_sidebar.hide()
	ui_sidebar.vpainter = self
	#SETUP THE EDITOR BUTTON:
	ui_activate_button = preload("res://addons/vpainter/vpainter_activate_button.tscn").instance()
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, ui_activate_button)
	ui_activate_button.hide()
	ui_activate_button.vpainter = self
	ui_activate_button.ui_sidebar = ui_sidebar

func _exit_tree():
	#REMOVE THE SIDEBAR:
	remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_SIDE_LEFT, ui_sidebar)
	if ui_sidebar:
		ui_sidebar.free()
	#REMOVE THE EDITOR BUTTON:
	remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, ui_activate_button)
	if ui_activate_button:
		ui_activate_button.free()
