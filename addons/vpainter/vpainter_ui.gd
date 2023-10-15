@tool
extends Control

var vpainter


func _enter_tree():
	%PaintButton.toggled.connect(_set_paint_tool)
	%FillButton.toggled.connect(_set_fill_tool)
	%SampleButton.toggled.connect(_set_sample_tool)
	%BlurButton.toggled.connect(_set_blur_tool)
	%DisplaceButton.toggled.connect(_set_displace_tool)
	set_tool_button(%PaintButton)
	
	%PrimaryColorPicker.color_changed.connect(_set_paint_color)
	%SecondaryColorPicker.color_changed.connect(_set_background_color)
	%FlipColors.pressed.connect(_flip_colors)
	
	for b in %ColorPresetsContainer.get_children():
		b.pressed.connect(_set_paint_color.bind(b.modulate))
	
	for blend_mode_button in %BlendModeContainer.get_children():
		blend_mode_button.pressed.connect(_set_blend_mode.bind(blend_mode_button))
	
	%BtnSizePressure.toggled.connect(_set_size_pressure)
	%BtnOpacityPressure.toggled.connect(_set_opacity_pressure)
	%SizeSlider.value_changed.connect(_set_brush_size)
	%OpacitySlider.value_changed.connect(_set_brush_opacity)
	%HardnessSlider.value_changed.connect(_set_brush_hardness)
	%SpacingSlider.value_changed.connect(_set_brush_spacing)
	%RandomizeSlider.value_changed.connect(_set_brush_random)
	
	
	%DuplicateButton.button_down.connect(_make_local_copy)
	%PrimitiveToMeshButton.button_down.connect(_convert_to_mesh)
	%ApplyPreviewMat.button_down.connect(_set_preview_material)
	
	vpainter.paint_color = %PrimaryColorPicker.color
	vpainter.paint_color_secondary = %SecondaryColorPicker.color


func _exit_tree():
	pass


func reset_tool():
	set_tool_button(%PaintButton)


func show_conversion(s:bool):
	%ConversionTool.visible = s
	%MainArea.visible = !s


func _set_preview_material():
	vpainter.set_preview_mat()


func _make_local_copy():
	vpainter._make_local_copy()


func _convert_to_mesh():
	vpainter._convert_to_mesh()


func _set_paint_color(value):
	%PrimaryColorPicker.set_pick_color(value)
	vpainter.paint_color = value


func _set_background_color(value):
	%SecondaryColorPicker.set_pick_color(value)
	vpainter.paint_color_secondary = value


func _flip_colors():
	var primary_color = %PrimaryColorPicker.color
	var secondary_color = %SecondaryColorPicker.color
	%PrimaryColorPicker.set_pick_color(secondary_color)
	%SecondaryColorPicker.set_pick_color(primary_color)
	vpainter.paint_color = secondary_color
	vpainter.paint_color_secondary = primary_color


func _reset_to_default_colors():
	%PrimaryColorPicker.set_pick_color(Color.WHITE)
	%SecondaryColorPicker.set_pick_color(Color.BLACK)
	vpainter.paint_color = Color.WHITE
	vpainter.paint_color_secondary = Color.BLACK


func _set_blend_mode(button:Button):
	for b in %BlendModeContainer.get_children():
		b.set_pressed(b == button)
	if button == %ModeMixButton:
		vpainter.blend_mode = vpainter.MIX
	elif button == %ModeAddButton:
		vpainter.blend_mode = vpainter.ADD
	elif button == %ModeSubstractButton:
		vpainter.blend_mode = vpainter.SUBTRACT
	elif button == %ModeMultiplyButton:
		vpainter.blend_mode = vpainter.MULTIPLY
	elif button == %ModeDivideButton:
		vpainter.blend_mode = vpainter.DIVIDE


func _input(event):
	if not vpainter.edit_mode:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			%PresetRed.pressed.emit()
		if event.keycode == KEY_2:
			%PresetGreen.pressed.emit()
		if event.keycode == KEY_3:
			%PresetBlue.pressed.emit()
		if event.keycode == KEY_4:
			%PresetBlack.pressed.emit()
		if event.keycode == KEY_5:
			%PresetWhite.pressed.emit()
		
		if event.keycode == KEY_X:
			%FlipColors.pressed.emit()
		if event.keycode == KEY_D:
			_reset_to_default_colors()
		
		if event.keycode == KEY_BRACELEFT:
			_set_brush_size(%SizeSlider.value - 0.05)
		if event.keycode == KEY_BRACERIGHT:
			_set_brush_size(%SizeSlider.value + 0.05)
		
		if event.keycode == KEY_APOSTROPHE :
			_set_brush_opacity(%OpacitySlider.value - 0.01)
		if event.keycode == KEY_BACKSLASH :
			_set_brush_opacity(%OpacitySlider.value + 0.01)


func _set_opacity_pressure(value):
	vpainter.pressure_opacity = value


func _set_size_pressure(value):
	vpainter.pressure_size = value


func _set_paint_tool(value):
	if value:
		vpainter.current_tool = "_paint_tool"
		show_pressure_settings(true)
		show_blend_mode_settings(true)
		set_tool_button(%PaintButton)


func _set_sample_tool(value):
	if value:
		vpainter.current_tool = "_sample_tool"
		show_pressure_settings(false)
		show_blend_mode_settings(false)
		set_tool_button(%SampleButton)


func _set_blur_tool(value):
	if value:
		vpainter.current_tool = "_blur_tool"
		show_pressure_settings(false)
		show_blend_mode_settings(false)
		set_tool_button(%BlurButton)

func _set_displace_tool(value):
	if value:
		vpainter.current_tool = "_displace_tool"
		show_pressure_settings(true)
		show_blend_mode_settings(false)
		set_tool_button(%DisplaceButton)


func _set_fill_tool(value):
	if value:
		vpainter.current_tool = "_fill_tool"
		show_pressure_settings(false)
		show_blend_mode_settings(true)
		set_tool_button(%FillButton)


func set_tool_button(set_true_on:Control):
	for tb in %ToolBox.get_children():
		tb.set_pressed(tb == set_true_on)


func _set_brush_size(value):
	value = clamp(value, 0.001, 10.0)
	%SizeSlider.value = value
	vpainter.brush_size = value
	vpainter.brush_cursor.scale = Vector3.ONE * value


func _set_brush_opacity(value):
	value = clamp(value, 0.001, 1.0)
	%OpacitySlider.value = value
	vpainter.brush_opacity = value


func _set_brush_hardness(value):
	value = clamp(value, 0.001, 1.0)
	%HardnessSlider.value = value
	vpainter.brush_hardness = value


func _set_brush_spacing(value):
	value = clamp(value, 0.001, 1.0)
	%SpacingSlider.value = value
	vpainter.brush_spacing = value


func _set_brush_random(value):
	value = clamp(value, 0.001, 1.0)
	%RandomizeSlider.value = value
	vpainter.brush_random = value


func show_pressure_settings(s:bool):
	%BtnSizePressure.visible = s
	%BtnOpacityPressure.visible = s


func show_blend_mode_settings(s:bool):
	%BlendModeSeparator.visible = s
	%BlendModesLabel.visible = s
	%BlendModeContainer.visible = s
