extends Node
class_name VPainterMeshTools

static func get_interpolated_color(position:Vector3, vertices:Array[Vector3], colors:Array[Color]):
	# vertices: Array of 3 Vector3 representing the triangle vertices
	# colors: Array of 3 Color representing the vertex colors
	
	var v0 = vertices[1] - vertices[0]
	var v1 = vertices[2] - vertices[0]
	var v2 = position - vertices[0]
	
	var d00 = v0.dot(v0)
	var d01 = v0.dot(v1)
	var d11 = v1.dot(v1)
	var d20 = v2.dot(v0)
	var d21 = v2.dot(v1)
	
	var denom = d00 * d11 - d01 * d01
	if denom == 0.0:
		return Color(0, 0, 0, 1) # Avoid division by zero
	
	var v = (d11 * d20 - d01 * d21) / denom
	var w = (d00 * d21 - d01 * d20) / denom
	var u = 1.0 - v - w
	
	# Interpolate colors
	return colors[0] * u + colors[1] * v + colors[2] * w

static func find_closet_3_points(mesh: ArrayMesh, position: Vector3) -> Array:
	if not mesh:
		return []

	var mesh_data := MeshDataTool.new()
	mesh_data.create_from_surface(mesh, 0)

	if mesh_data.get_face_count() == 0:
		return []
	
	var verticies := []

	for i in mesh_data.get_vertex_count():
		var vertex := mesh_data.get_vertex(i)
		var d := position.distance_squared_to(vertex)
		
		verticies.push_back([i, d])

		if verticies.size() > 3:
			verticies.sort_custom(_compare_distance_to_position)
			verticies = verticies.slice(0, 3)
	
	# Return the closest 3 vertices
	for i in verticies.size():
		verticies[i] = verticies[i][0]

	return verticies

static func _compare_distance_to_position(a, b) -> int:
	return a[1] < b[1]
	
static func get_facing_orientation(bounding_box_size: Vector3) -> int:
	match bounding_box_size.min_axis_index():
		0:
			return QuadMesh.Orientation.FACE_X
		1:
			return QuadMesh.Orientation.FACE_Y
		
	return QuadMesh.Orientation.FACE_Z
		
