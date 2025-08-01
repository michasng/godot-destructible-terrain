class_name Main
extends Node2D


@export var chunk_size := 100
@export var chunk_grid_size := Vector2(10,5)
@export var brush_radius := 40
@export var min_movement_update := 5


var previous_brush_position := Vector2.ZERO

var chunk_grid: Array[Array] = [] # Array[Array[Chunk]]

@onready var chunks: Node2D = $Chunks
@onready var brush_area: Polygon2D = $BrushArea
@onready var rigid_bodies: Node2D = $RigidBodies

var chunk_scene: PackedScene = preload("res://scenes/chunk.tscn")
var ball_scene: PackedScene = preload("res://scenes/ball.tscn")


func _ready() -> void:
	_spawn_chunks()
	_create_brush_shape()


func _spawn_chunks() -> void:
	for i in range(chunk_grid_size.x):
		chunk_grid.push_back([])
		for j in range(chunk_grid_size.y):
			var chunk: Chunk = chunk_scene.instantiate()
			chunk.default_polygon = [
				Vector2(chunk_size*i,chunk_size*j),
				Vector2(chunk_size*(i+1),chunk_size*j),
				Vector2(chunk_size*(i+1),chunk_size*(j+1)),
				Vector2(chunk_size*i,chunk_size*(j+1))
			]
			chunk_grid[-1].push_back(chunk)
			chunks.add_child(chunk)


func _create_brush_shape() -> void:
	var point_count := 15
	var polygon = PackedVector2Array()
	for index in range(point_count):
		var angle = lerp(-PI, PI, float(index)/point_count)
		polygon.push_back(Vector2(cos(angle), sin(angle)) * brush_radius)
	brush_area.polygon = polygon


func _process(_delta: float) -> void:
	if Input.is_action_pressed("click_left") and \
		previous_brush_position.distance_to(brush_area.position) > min_movement_update:
		_carve()
		previous_brush_position = brush_area.position
	
	elif Input.is_action_pressed("click_right") and \
		previous_brush_position.distance_to(brush_area.position) > min_movement_update:
		_add()
		previous_brush_position = brush_area.position
	
	if Input.is_action_pressed("ui_accept"):
		var ball: Node2D = ball_scene.instantiate()
		ball.position = brush_area.position + Vector2(randi()%10,0)
		rigid_bodies.add_child(ball)


func _input(event) -> void:
	if event is InputEventMouseMotion:
		brush_area.position = event.global_position


func _carve() -> void:
	var polygon := Transform2D(0, brush_area.position) * (brush_area.polygon)
	for chunk in _approximate_affected_chunks():
		chunk.carve(polygon)


func _add() -> void:
	var polygon := brush_area.transform * brush_area.polygon
	for chunk in _approximate_affected_chunks():
		chunk.add(polygon)


func _approximate_affected_chunks() -> Array[Chunk]:
	var affected_chunks: Array[Chunk] = []
	var half_diagonal = sqrt(2) * chunk_size / 2
	for chunk: Chunk in chunks.get_children():
		var chunk_top_left := chunk.default_polygon[0]
		var chunk_center := chunk_top_left + Vector2(chunk_size, chunk_size)/2
		if chunk_center.distance_to(brush_area.position) <= brush_radius + half_diagonal:
			affected_chunks.push_back(chunk)
	return affected_chunks
