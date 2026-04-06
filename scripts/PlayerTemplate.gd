## Class: "scripts/PlayerTemplate.gd"
## Inherits: CharacterBody3D < PhysicsBody3D < CollisionObject3D < Node3D < Node < Object
##
## Скрипт управления персонажем в стиле Soulslike. 
## Обрабатывает передвижение, боевку (комбо), перекаты и дерево анимаций.
extends CharacterBody3D

## Путь к узлу AnimationTree
@export var PlayerAnimationTree: NodePath 
## Узел дерева анимаций
@onready var animation_tree = get_node(PlayerAnimationTree)
## Узел управления потоком анимаций (AnimationNodeStateMachinePlayback)
@onready var playback = animation_tree.get("parameters/playback")

## Путь к узлу меша игрока
@export var PlayerCharacterMesh: NodePath
## Узел меша (модели) игрока
@onready var player_mesh = get_node(PlayerCharacterMesh)

@export_group("Параметры движения")
## Сила гравитации
@export var gravity: float = 9.8
## Сила прыжка
@export var jump_force: float = 9
## Скорость ходьбы
@export var walk_speed: float = 1.3
## Скорость бега
@export var run_speed: float = 5.5
## Сила рывка (для перекатов и спец-атак)
@export var dash_power: float = 12 

## Имя узла анимации переката
var roll_node_name: String = "Roll"
## Имя узла анимации покоя
var idle_node_name: String = "Idle"
## Имя узла анимации ходьбы
var walk_node_name: String = "Walk"
## Имя узла анимации бега
var run_node_name: String = "Run"
## Имя узла анимации прыжка
var jump_node_name: String = "Jump"
## Имя узла первой атаки
var attack1_node_name: String = "Attack1"
## Имя узла второй атаки
var attack2_node_name: String = "Attack2"
## Имя узла сильной атаки
var bigattack_node_name: String = "BigAttack"

## Флаг состояния атаки
var is_attacking: bool = false
## Флаг состояния переката
var is_rolling: bool = false
## Флаг состояния ходьбы
var is_walking: bool = false
## Флаг состояния бега
var is_running: bool = false

## Вектор направления движения
var direction: Vector3 = Vector3()
## Горизонтальная составляющая скорости
var horizontal_velocity: Vector3 = Vector3()
## Значение поворота при прицеливании
var aim_turn: float = 0.0
## Результирующий вектор перемещения
var movement: Vector3 = Vector3()
## Вертикальная составляющая скорости (гравитация/прыжок)
var vertical_velocity: Vector3 = Vector3()
## Текущая скорость движения
var movement_speed: float = 0.0
## Угловое ускорение поворота
var angular_acceleration: float = 10.0
## Общее ускорение персонажа
var acceleration: float = 15.0

func _ready():
	direction = Vector3.BACK.rotated(Vector3.UP, $Camroot/h.global_transform.basis.get_euler().y)

func _input(event):
	if event is InputEventMouseMotion:
		aim_turn = -event.relative.x * 0.015 
	
	if event.is_action_pressed("aim"):
		direction = $Camroot/h.global_transform.basis.z

## Выполняет механику переката. Проверяет возможность прерывания текущих анимаций и применяет импульс [member dash_power].
func roll():
	if Input.is_action_just_pressed("roll"):
		var current = playback.get_current_node()
		if !roll_node_name in current and !jump_node_name in current and !bigattack_node_name in current:
			playback.start(roll_node_name)
			horizontal_velocity = direction * dash_power
			
## Инициирует первую атаку в цепочке комбо. Возможна только при нахождении на земле в состоянии покоя или ходьбы.
func attack1():
	if (idle_node_name in playback.get_current_node() or walk_node_name in playback.get_current_node()) and is_on_floor():
		if Input.is_action_just_pressed("attack"):
			if !is_attacking:
				playback.travel(attack1_node_name)
				
## Переводит анимацию во вторую фазу атаки, если в данный момент проигрывается [member attack1_node_name].
func attack2():
	if attack1_node_name in playback.get_current_node():
		if Input.is_action_just_pressed("attack"):
			playback.travel(attack2_node_name)
			
## Шаблон для реализации третьей атаки в цепочке комбо.
func attack3():
	if attack2_node_name in playback.get_current_node(): 
		if Input.is_action_just_pressed("attack"):
			pass 
	
## Выполняет специальную атаку из состояния переката, если нажата клавиша атаки.
func rollattack():
	if roll_node_name in playback.get_current_node(): 
		if Input.is_action_just_pressed("attack"):
			playback.travel(bigattack_node_name)
			
## Выполняет усиленную атаку из состояния бега, добавляя импульс движения.
func bigattack():
	if run_node_name in playback.get_current_node():
		if Input.is_action_just_pressed("attack"):
			horizontal_velocity = direction * dash_power
			playback.travel(bigattack_node_name)
	
func _physics_process(delta):
	rollattack()
	bigattack()
	attack1()
	attack2()
	roll()
	
	var on_floor = is_on_floor()
	var h_rot = $Camroot/h.global_transform.basis.get_euler().y
	
	movement_speed = 0
	angular_acceleration = 10
	acceleration = 15

	if not on_floor: 
		vertical_velocity += Vector3.DOWN * gravity * 2 * delta
	else: 
		vertical_velocity = -get_floor_normal() * gravity / 3
	
	var current_node = playback.get_current_node()
	if (attack1_node_name in current_node) or (attack2_node_name in current_node) or (bigattack_node_name in current_node): 
		is_attacking = true
	else: 
		is_attacking = false

	if bigattack_node_name in current_node: 
		acceleration = 3

	if roll_node_name in current_node: 
		is_rolling = true
		acceleration = 2
		angular_acceleration = 2
	else: 
		is_rolling = false
	
	if Input.is_action_just_pressed("jump") and !is_attacking and !is_rolling and on_floor:
		vertical_velocity = Vector3.UP * jump_force
		
	var input_dir = Vector2(
		Input.get_action_strength("left") - Input.get_action_strength("right"),
		Input.get_action_strength("forward") - Input.get_action_strength("backward")
	)
	
	if input_dir.length() > 0:
		direction = Vector3(input_dir.x, 0, input_dir.y)
		direction = direction.rotated(Vector3.UP, h_rot).normalized()
		is_walking = true
		
		if Input.is_action_pressed("sprint") and is_walking: 
			movement_speed = run_speed
			is_running = true
		else: 
			movement_speed = walk_speed
			is_running = false
	else: 
		is_walking = false
		is_running = false
		
	if Input.is_action_pressed("aim"):
		player_mesh.rotation.y = lerp_angle(player_mesh.rotation.y, $Camroot/h.rotation.y, delta * angular_acceleration)
	else:
		player_mesh.rotation.y = lerp_angle(player_mesh.rotation.y, atan2(direction.x, direction.z) - rotation.y, delta * angular_acceleration)
	
	if is_attacking or is_rolling: 
		horizontal_velocity = horizontal_velocity.lerp(direction.normalized() * 0.01, acceleration * delta)
	else: 
		horizontal_velocity = horizontal_velocity.lerp(direction.normalized() * movement_speed, acceleration * delta)
	
	velocity.z = horizontal_velocity.z + vertical_velocity.z
	velocity.x = horizontal_velocity.x + vertical_velocity.x
	velocity.y = vertical_velocity.y
	
	move_and_slide()

	animation_tree["parameters/conditions/IsOnFloor"] = on_floor
	animation_tree["parameters/conditions/IsInAir"] = !on_floor
	animation_tree["parameters/conditions/IsWalking"] = is_walking
	animation_tree["parameters/conditions/IsNotWalking"] = !is_walking
	animation_tree["parameters/conditions/IsRunning"] = is_running
	animation_tree["parameters/conditions/IsNotRunning"] = !is_running
