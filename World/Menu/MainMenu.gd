extends Node2D

const newGame_button_animation = preload("res://World/Menu/Menu_NewGame_Animation.tscn")
var level_select = preload("res://World/Level_Select/LevelSelect.tscn")
onready var bg_playgame = $bg_Menu_PlayGame

#onready var mouse = get_node("mouse")

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	bg_playgame.hide()

func change_scene() -> void:
	queue_free()
	get_tree().change_scene("res://World/Level_Select/LevelSelect.tscn")  

func _on_CreditButton_pressed() -> void:
	get_tree().change_scene("res://World/Level_Credits/LevelCredits.tscn") 
	pass

func _on_ButtonQuit_pressed():
	get_tree().quit()


func _on_ButtonPlayGame_pressed() -> void:
	#var newGame_animation = newGame_button_animation.instance()
	#get_parent().add_child(newGame_animation)
	#newGame_animation.global_position = Vector2(319.913,179.802)
	bg_playgame.show()
	bg_playgame.play()
	var timer = Timer.new()
	timer.set_wait_time(0.85)
	timer.set_one_shot(true)
	timer.connect("timeout", self, "change_scene")
	add_child(timer)
	timer.start()
