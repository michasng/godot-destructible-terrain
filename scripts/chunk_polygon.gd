class_name ChunkPolygon
extends CollisionPolygon2D

@onready var polygon_2d: Polygon2D = $Polygon2D


func _ready() -> void:
	polygon_2d.polygon = polygon


func update_polygon(value: PackedVector2Array) -> void:
	polygon = value
	polygon_2d.polygon = value
