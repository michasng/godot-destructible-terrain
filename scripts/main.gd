class_name Main
extends Node2D


@export var quadrant_size := 100
@export var quadrant_grid_size := Vector2(10,5)
@export var carve_radius := 40
@export var min_movement_update := 5


var old_mouse_pos := Vector2.ZERO
var mouse_pos := Vector2.ZERO

var quadrants_grid: Array[Array] = [] # Array[Array[Quadrant]]

@onready var quadrants: Node2D = $Quadrants
@onready var carve_area: Polygon2D = $CarveArea
@onready var rigid_bodies: Node2D = $RigidBodies

var QuadrantScene: PackedScene = preload("res://scenes/quadrant.tscn")
var Ball: PackedScene = preload("res://scenes/ball.tscn")


func _ready():
	_spawn_quadrants()
	_make_mouse_circle()


func _spawn_quadrants():
	for i in range(quadrant_grid_size.x):
		quadrants_grid.push_back([])
		for j in range(quadrant_grid_size.y):
			var quadrant: Quadrant = QuadrantScene.instantiate()
			quadrant.default_quadrant_polygon = [
				Vector2(quadrant_size*i,quadrant_size*j),
				Vector2(quadrant_size*(i+1),quadrant_size*j),
				Vector2(quadrant_size*(i+1),quadrant_size*(j+1)),
				Vector2(quadrant_size*i,quadrant_size*(j+1))
			]
			quadrants_grid[-1].push_back(quadrant)
			quadrants.add_child(quadrant)


func _make_mouse_circle():
	var nb_points = 15
	var pol = []
	for i in range(nb_points):
		var angle = lerp(-PI, PI, float(i)/nb_points)
		pol.push_back(mouse_pos + Vector2(cos(angle), sin(angle)) * carve_radius)
	carve_area.polygon = pol


func _process(_delta):
	if Input.is_action_pressed("click_left"):
		if old_mouse_pos.distance_to(mouse_pos) > min_movement_update:
			_carve()
			old_mouse_pos = mouse_pos
	
	elif Input.is_action_pressed("click_right"):
		if old_mouse_pos.distance_to(mouse_pos) > min_movement_update:
			_add()
			old_mouse_pos = mouse_pos
	
	if Input.is_action_pressed("ui_accept"):
		var ball: Node2D = Ball.instantiate()
		ball.position = get_global_mouse_position() + Vector2(randi()%10,0)
		rigid_bodies.add_child(ball)


func _input(event):
	if event is InputEventMouseMotion:
		mouse_pos = get_global_mouse_position()
		carve_area.position = mouse_pos


func _carve():
	var mouse_polygon = Transform2D(0, mouse_pos) * (carve_area.polygon)
	var four_quadrants = _get_affected_quadrants(mouse_pos)
	for quadrant in four_quadrants:
		quadrant.carve(mouse_polygon)


func _add():
	var mouse_polygon = Transform2D(0, mouse_pos) * (carve_area.polygon)
	var four_quadrants = _get_affected_quadrants(mouse_pos)
	for quadrant in four_quadrants:
		quadrant.add(mouse_polygon)


func _get_affected_quadrants(pos):
	"""
	Returns array of Quadrants that are affected by
	the carving. Not the best function: sometimes it
	returns some quadrants that are not affected
	"""
	var affected_quadrants = []
	var half_diag = sqrt(2)*quadrant_size/2
	for quadrant in $Quadrants.get_children():
		var quadrant_top_left = quadrant.default_quadrant_polygon[0]
		var quadrant_center = quadrant_top_left + Vector2(quadrant_size, quadrant_size)/2
		if quadrant_center.distance_to(pos) <= carve_radius + half_diag:
			affected_quadrants.push_back(quadrant)
	return affected_quadrants
