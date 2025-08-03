class_name Chunk
extends Node2D

var default_polygon: PackedVector2Array = []

@onready var static_body: StaticBody2D = $StaticBody2D
@onready var ChunkPolygonScene: PackedScene = preload("res://scenes/chunk_polygon.tscn")


func _ready() -> void:
	static_body.add_child(_new_chunk_polygon(default_polygon))


func reset() -> void:
	for chunk_polygon in static_body.get_children():
		chunk_polygon.queue_free()
	static_body.add_child(_new_chunk_polygon(default_polygon))


func carve(clipping_polygon: PackedVector2Array) -> void:
	"""
	Carves `clipping_polygon` away from the chunk
	"""
	for chunk_polygon in static_body.get_children():
		var clipped_polygons := Polygons.clip(chunk_polygon.polygon, clipping_polygon)
		
		match clipped_polygons.size():
			0:
				# clipping_polygon completely overlaps chunk_polygon
				chunk_polygon.queue_free()
			1:
				# Clipping produces only one polygon
				chunk_polygon.update_polygon(clipped_polygons[0])
			_:
				# if more polygons, simply add all of them to the chunk
				chunk_polygon.update_polygon(clipped_polygons[0])
				for i in range(clipped_polygons.size() - 1):
					static_body.add_child(_new_chunk_polygon(clipped_polygons[i + 1]))


func add(adding_polygon: PackedVector2Array) -> void:
	"""
	Adds the chunk-intersecting parts of `adding_polygon` to the chunk
	"""
	var intersected_adding_polygons := Geometry2D.intersect_polygons(default_polygon, adding_polygon)
	if len(intersected_adding_polygons) == 0:
		# adding_polygon is not within the chunk
		return

	# could only occur if adding_polygon itself had a hole, which is unsupported
	assert(not Polygons.has_hole(intersected_adding_polygons))

	var polygons: Array[PackedVector2Array] = []
	for child: ChunkPolygon in static_body.get_children():
		polygons.append(child.polygon)
	polygons.append_array(intersected_adding_polygons)

	polygons = Polygons.merge(polygons)
	assert(not Polygons.has_hole(polygons))
	
	_assign_polygons(polygons)


func _assign_polygons(polygons: Array[PackedVector2Array]) -> void:
	for child in static_body.get_children():
		child.queue_free()
	for polygon in polygons:
		var chunk_polygon = _new_chunk_polygon(polygon)
		static_body.add_child(chunk_polygon) # sometimes throws "Convex decomposing failed"


func _new_chunk_polygon(polygon: PackedVector2Array) -> ChunkPolygon:
	var chunk_polygon: ChunkPolygon = ChunkPolygonScene.instantiate()
	chunk_polygon.polygon = polygon
	return chunk_polygon
