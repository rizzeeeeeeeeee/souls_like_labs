## Class: "scripts/CameraControl.gd"
## Inherits: Node3D < Node < Object
##
## Скрипт управления камерой от третьего лица (TPS). 
## Поддерживает управление мышью, геймпадом и автоматический поворот за игроком.
extends Node3D

## Путь к узлу меша игрока для ориентации камеры
@export var PlayerCharacterMesh: NodePath

## Текущий поворот камеры по горизонтали
var camrot_h: float = 0.0
## Текущий поворот камеры по вертикали
var camrot_v: float = 0.0

@export_group("Настройки ограничений")
## Максимальный угол наклона камеры вверх (рекомендуется 75)
@export var cam_v_max: int = 75
## Минимальный угол наклона камеры вниз (рекомендуется -55)
@export var cam_v_min: int = -55

@export_group("Чувствительность")
## Множитель чувствительности для правого стика геймпада
@export var joystick_sensitivity: int = 20
## Чувствительность мыши по горизонтали
var h_sensitivity: float = 0.1
## Чувствительность мыши по вертикали
var v_sensitivity: float = 0.1

@export_group("Плавность")
## Множитель скорости авто-поворота (чем меньше значение, тем больше радиус вращения)
var rot_speed_multiplier: float = 0.15 
## Ускорение сглаживания по горизонтали
var h_acceleration: int = 10
## Ускорение сглаживания по вертикали
var v_acceleration: int = 10

## Вектор ввода с правого стика геймпада
var joyview: Vector2 = Vector2()

func _ready():
	# Захват курсора мыши внутри окна игры
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Исключение родительского узла (игрока) из коллизий камеры (RayCast)
	$h/v/Camera3D.add_exception(get_parent())
	
func _input(event):
	# Обработка движения мыши
	if event is InputEventMouseMotion:
		# Запуск таймера задержки, чтобы авто-поворот не мешал ручному управлению
		$control_stay_delay.start()
		camrot_h += -event.relative.x * h_sensitivity
		camrot_v += event.relative.y * v_sensitivity
		
## Обрабатывает ввод с джойстика/геймпада для вращения камеры. 
## Считывает действия lookleft/lookright и lookup/lookdown.
func _joystick_input():
	if (Input.is_action_pressed("lookup") || Input.is_action_pressed("lookdown") || Input.is_action_pressed("lookleft") || Input.is_action_pressed("lookright")):
		$control_stay_delay.start()
		joyview.x = Input.get_action_strength("lookleft") - Input.get_action_strength("lookright")
		joyview.y = Input.get_action_strength("lookup") - Input.get_action_strength("lookdown")
		camrot_h += joyview.x * joystick_sensitivity * h_sensitivity
		camrot_v += joyview.y * joystick_sensitivity * v_sensitivity 
		
func _physics_process(delta):
	# Опрос ввода с геймпада
	_joystick_input()
		
	# Ограничение вертикального вращения (чтобы камера не совершала "мертвую петлю")
	camrot_v = clamp(camrot_v, cam_v_min, cam_v_max)
	
	# Расчет скорости автоматического следования камеры за мешем персонажа
	var mesh_front = get_node(PlayerCharacterMesh).global_transform.basis.z
	var auto_rotate_speed = (PI - mesh_front.angle_to($h.global_transform.basis.z)) * get_parent().horizontal_velocity.length() * rot_speed_multiplier
	
	# Если ручной ввод отсутствует (таймер задержки истек) — камера плавно следует за игроком
	if $control_stay_delay.is_stopped():
		$h.rotation.y = lerp_angle($h.rotation.y, get_node(PlayerCharacterMesh).global_transform.basis.get_euler().y, delta * auto_rotate_speed)
		camrot_h = $h.rotation_degrees.y
	else:
		# Если игрок вращает камеру сам — применяем сглаживание к ручному вводу
		$h.rotation_degrees.y = lerp($h.rotation_degrees.y, camrot_h, delta * h_acceleration)
	
	# Применение вертикального вращения к узлу наклона
	$h/v.rotation_degrees.x = lerp($h/v.rotation_degrees.x, camrot_v, delta * v_acceleration)
