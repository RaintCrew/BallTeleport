extends KinematicBody2D

export var RUN_SPEED = 100 		# velocidad lateral de Player al caminar
export var GRAVITY = 10 			# aceleracion vertical que disminuye la velocidad vertical del Player
export var FLOOR = Vector2(0,-1) # vector normal que el physics engine usa para frenar con pisos y paredes
export var MAX_FALL_SPEED = 200 	# lo mas rapido que puede caer el Player por gravedad
export var FRICTION = 150			# this force will oppose the knockback force
export var JUMP_FORCE = 165 		# qué tan alto puede saltar el jugador
export var INVINCIBILITY_TIME = 2	# invincibility duration 

const PISTOL_AMMO = 6
var stats = PlayerStats				# Access to the Singleton with the stats.
var knockback = Vector2.ZERO		# knockback yay
var velocity = Vector2() 			# Vector (x,y) donde x/y define cuanto se mueve horizontal/verticalmente en cada frame.
var target_running_velocity = 0		# Velocidad a la que está intentando llegar. Se usa para lograr la aceleracion y desaceleracion
var ammo = PISTOL_AMMO 				# Numero de balas en el arma. Se recarga con Teleport
var is_player_hurt = false

var can_throw_teleport_ball = true	# Puede arrojar la teleport ball, o esta en el aire y no puede lanzarla
var has_landed = true				# Se usa para ejecutar code en el primer instante que aterriza en suelo
var has_tpball_traveled_enough = false
var will_camera_shake_on_gunfire = true

onready var player_sprite = $PlayerSprite
onready var animation_player = $AnimationPlayer
onready var blink_animation_player = $BlinkAnimationPlayer
onready var crosshair = get_node("Crosshair") 			# Referencia a la crosshair
onready var camera = get_parent().get_node("Camera")	# Referencia a la camara
onready var gun = get_node("Gun") 						# Referencia al arma de la que disparas
onready var floating_teleport_ball = get_node("Ball") 	# Referencia a teleport ball flotando al lado tuyo
onready var teleport_ball = null						# Referencia a teleport ball lanzada a la cual te teleportas
onready var hurtbox = $Hurtbox
onready var player_knockback_collisionShape = $PlayerKnockback/CollisionShape2D


onready var bullet_scene = preload("res://Player/PlayerBullet.tscn") 					# Referencia a escena de bala
onready var teleport_ball_scene = preload("res://Player/TeleportBall.tscn") 			# Referencia a escena de teleport ball
onready var smoke_particle_scene = preload("res://Player/PlayerJumpSmokeParticle.tscn")	# Referencia a escena de particulas de humo
onready var teleport_particle_scene = preload("res://Player/TeleportParticles.tscn")	# Referencia a escena de particulas de teleport
# Called when the node enters the scene tree for the first time.
func _ready():
	Global.player = self
	# no_health is the signal we're connecting to
	# self is this object (like "this" in any othe major programming language xd)
	# "die" is the function that will be called.
	stats.connect("no_health",self,"die")
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	

	# this force will oppose that of the knockback
	knockback = knockback.move_toward(Vector2.ZERO, FRICTION * delta)
	knockback = move_and_slide(knockback)
	# Controles tecla "A" y "D" para moverse lateralmente
	# Al no presionar ninguna tecla, el Player se detiene lateralmente
	# Acerca target_running_velocity: 
	# 	por ejemplo al presionar "D", el personaje fija que "quiero llegar a RUN_SPEED".
	# 	Después, la velocity suavemente cambia hasta llegar a cual sea el valor de target_running_velocity
	if Input.is_key_pressed(KEY_D):
		target_running_velocity = RUN_SPEED
		animation_player.play("run_backwards")
		
	elif Input.is_key_pressed(KEY_A):
		target_running_velocity = -RUN_SPEED
		animation_player.play("run_backwards")
		
	else:
		target_running_velocity = 0
		if !is_player_hurt and !is_on_floor():
			animation_player.play("idle")
		if !is_player_hurt and !is_on_floor() and (velocity.y >= 1):
			animation_player.play("falling")
	
	# Las siguientes formulas de velocity.x buscan suavizar su valor hasta que se vuelva target_running_velocity
	# [Formula original:  x += (target - x) * 0.1]
	# [Al llamar a esta funcion en cada frame, lo que haces es 
	#   acercar a "x" 10% del camino que le falta para llegar a target]
	if target_running_velocity == 0: # Si esta intentando frenar hasta cero
		velocity.x += (target_running_velocity - velocity.x) * 0.7
	else:							# Si esta intentando acelerar
		velocity.x += (target_running_velocity - velocity.x) * 0.4

	
	# Limitar que el Player no caiga muy rapido
	if velocity.y < MAX_FALL_SPEED: 
		velocity.y += GRAVITY
	
	# Desplazar al Player de acuerdo al velocity,
	# evaluando por colisiones en el proceso
	velocity = move_and_slide(velocity, FLOOR)
	
	# Ubicar la mira donde este el mouse
	crosshair.global_position = get_global_mouse_position()
	# Rotar la pistola para que apunte a donde este la mira
	gun.look_at(get_global_mouse_position())
	
	# Hace desaparecer la teleport ball flotando al lado tuyo
	# si esta volando y por lo tanto, no puede ser arrojada
	floating_teleport_ball.visible = can_throw_teleport_ball
	
	$Ammo_Label.text = str(ammo) # Mostrar en texto la municion del arma
	
	# El jugador y el arma se voltean hacia donde este la crosshair
	if crosshair.global_position.x < global_position.x:
		player_sprite.flip_h = true
		gun.flip_v = true
	else:
		player_sprite.flip_h = false
		gun.flip_v = false
	
	# Cuando el Player aterriza en suelo, su sprite se deforma
	# Este codigo es el que se encarga en cada frame de suavemente
	# acomodar la sprite de vuelta a su forma normal
	player_sprite.scale.y += (1 - player_sprite.scale.y) * 0.2
	player_sprite.scale.x += (1 - player_sprite.scale.x) * 0.2
	player_sprite.position.y += (0 - player_sprite.position.y) * 0.2
	# Suaviza el retorno del arma a su posicion normal despues del recoil
	gun.position.x += (0 - gun.position.x) * 0.2
	gun.position.y += (0 - gun.position.y) * 0.2
	
	# Ejecutar efectos en el primer instante que el Player aterriza en suelo
	if is_on_floor():
		if has_landed == false:
			player_sprite.position.y += 2
			player_sprite.scale.y = 0.7
			player_sprite.scale.x = 1.3
			
			has_landed = true
			create_smoke_particles()
			$Audio_Hit.play()
	else: 
		has_landed = false
		

func jump():
	if is_on_floor():
		velocity.y = -JUMP_FORCE
		player_sprite.scale.x = 0.7
		player_sprite.scale.y = 1.3
		player_sprite.position.y -= 2
		create_smoke_particles()
		$Audio_Jump.play()
	


# Funcion para disparar arma
func fire():
	if ammo > 0:	# Tienes que tener municion para disparar
		# Crear una instancia de bala, fijar su origen en el arma,
		# y despues crearla en el nivel con "add_child"
		var bullet = bullet_scene.instance()	
		bullet.position = gun.get_node("Gun_Tip").get_global_position()
		bullet.destination = crosshair.get_global_position()
		get_parent().add_child(bullet)
		
		ammo -= 1
		
		# Gun recoil vfx
		var recoil = gun.global_position.direction_to(crosshair.global_position)
		recoil *= 6
		gun.global_position -= recoil
		$Audio_Shoot.play()
		if will_camera_shake_on_gunfire:
			camera.activate_shake(1.6,0.1) # (shake_intensity, shake_duration)



# Funcion para arrojar teleport ball
func throw_teleport_ball():
	can_throw_teleport_ball = false	# Ya no puedes arrojar la teleport ball
	
	# Crear una instancia de teleport ball, fijar su origen en el arma,
	# y despues crearla en el nivel con "add_child"
	teleport_ball = teleport_ball_scene.instance()
	teleport_ball.position = gun.get_node("Gun_Tip").get_global_position()
	get_parent().add_child(teleport_ball)
	

# Funcion de teleportarse hacia la teleport ball
func teleport():
	if has_tpball_traveled_enough:
		create_tp_particles()
		# Relocar al jugador donde este la teleport_ball
		self.global_position = teleport_ball.get_global_position()
		OS.delay_msec(60) # Frame freeze
		camera.activate_shake(2.0, 0.4)
		create_tp_particles()
		$Audio_Teleport.play()
		velocity.y = 0					# El momentum de caida no se mantiene al teleportarse
		regain_teleport_ball()	# Re-obtienes la teleport ball y puedes tirarla de nuevo
		teleport_ball.queue_free()		# Borrar la teleport ball que estaba viajando
		reload()	# Teleportarse es lo que recarga tus armas

# Funcion para recargar tu arma. Suele ejecutarse al teleportarse
# Si vamos a agregar mas armas, esta funcion se modifica para cada tipo de arma
func reload():
	ammo = PISTOL_AMMO

# Funcion para recuperar la teleport ball
# Esta en su opcion porque probablemente hagamos algunos vfx
# cuando ocurra. Esos se pondrian aqui.
func regain_teleport_ball():
	can_throw_teleport_ball = true
	has_tpball_traveled_enough = false

func die():
	if teleport_ball: # Si la tp ball esta volando, debe ser eliminada antes de quitar al player
		teleport_ball.queue_free()
	OS.delay_msec(100)
	camera.display_gameover()
	queue_free()

	
# Esta funcion se llama cada vez que cualquier input se detecta
# "input" siendo una tecla presionada, mouse clickeada, etc.
func _input(event):
	if event.is_action_pressed("jump"):
		jump()
	
	if event is InputEventMouseButton:
		match event.button_index:		# Esto es como el switch-case statements en C++/Python
			BUTTON_LEFT:				# Clic-izquierdo = disparar
				if event.is_pressed():	# Registrar solo el clic, y no su release o el dejarlo presionado
					fire()
			BUTTON_RIGHT:						# Clic-derecho = arrojar teleport ball/teleportarse
				if event.is_pressed():			
					if can_throw_teleport_ball:	# Depende de si la teleport ball esta disponible o no
												# O arrojas la teleport ball, o te teleportas a ella
						throw_teleport_ball()
					else:
						teleport()
		
func _on_PlayerKnockback_area_entered(area):
	knockback = area.knockback_vector * area.knockback_force
	player_knockback_collisionShape.set_deferred("disabled",true)


func _on_Hurtbox_area_entered(area):
	stats.health -= area.damage
	hurtbox.start_invincibility(INVINCIBILITY_TIME)

func create_smoke_particles():
	var smoke_particles = smoke_particle_scene.instance()	
	smoke_particles.global_position = Vector2(global_position.x, global_position.y+8)
	smoke_particles.emitting = true
	get_parent().add_child(smoke_particles)

func create_tp_particles():
	var tp_particles = teleport_particle_scene.instance()	
	tp_particles.global_position = Vector2(global_position.x, global_position.y)
	get_parent().add_child(tp_particles)


func _on_Trigger_body_entered(body):
	if body == self:
		get_tree().change_scene("res://World/Level2/Level2.tscn")
		get_tree().paused = false

func tpball_traveled_enough():
	has_tpball_traveled_enough = true

func _on_Hurtbox_invincibility_started():
	blink_animation_player.play("Start")


func _on_Hurtbox_invincibility_ended():
	blink_animation_player.play("Stop")
	player_knockback_collisionShape.disabled = false
