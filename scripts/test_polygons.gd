class_name TestPolygons
extends Node

@onready var static_body: StaticBody2D = $StaticBody2D
@onready var outer_chunk_polygon: ChunkPolygon = $StaticBody2D/OuterChunkPolygon
@onready var inner_chunk_polygon: ChunkPolygon = $StaticBody2D/InnerChunkPolygon
@onready var result_chunk_polygon: ChunkPolygon = $StaticBody2D/ResultChunkPolygon

@onready var ChunkPolygonScene: PackedScene = preload("res://scenes/chunk_polygon.tscn")

func _ready():
	_test_resolve_holes()


func _test_resolve_holes():
	var outer_polygon := outer_chunk_polygon.transform * outer_chunk_polygon.polygon
	var inner_polygon := inner_chunk_polygon.transform * inner_chunk_polygon.polygon
	
	var clipped_polygons := Polygons.clip(outer_polygon, inner_polygon)
	_show_result(clipped_polygons)


func _show_result(result: Array[PackedVector2Array]) -> void:
	print("result: ", result)
	for polygon in result:
		var chunk_polygon: ChunkPolygon = ChunkPolygonScene.instantiate()
		static_body.add_child(chunk_polygon)
		chunk_polygon.update_polygon(polygon)
