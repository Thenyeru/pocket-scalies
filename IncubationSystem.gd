# SISTEMA DE INCUBAÇÃO DO OVO
class_name IncubationSystem
extends RefCounted

# Configurações de incubação
var total_time: float = 300.0  # 5 minutos
var remaining_time: float = 300.0
var pet_reduction: float = 10.0  # Cada carinho reduz 10 segundos
var pet_cooldown: float = 1.0  # 1 segundo entre carinhos
var last_pet_time: float = 0.0

# Referência ao controlador
var controller: TamagotchiController

func connect_to_controller(main_controller: TamagotchiController):
	"""Conecta este sistema ao controlador principal"""
	controller = main_controller

func setup_incubation_bar(bar: ProgressBar):
	"""Configura a barra de incubação"""
	if bar:
		bar.min_value = 0
		bar.max_value = total_time
		bar.value = total_time - remaining_time

func process(delta: float):
	"""Processa o tempo de incubação"""
	remaining_time -= delta
	if remaining_time < 0:
		remaining_time = 0

func should_hatch() -> bool:
	"""Verifica se é hora de chocar"""
	return remaining_time <= 0

func pet_egg() -> bool:
	"""Acaricia o ovo, retorna true se conseguiu"""
	var current_time = Time.get_unix_time_from_system()
	
	# Verifica cooldown
	if current_time - last_pet_time < pet_cooldown:
		return false
	
	last_pet_time = current_time
	
	# Reduz tempo de incubação
	remaining_time -= pet_reduction
	if remaining_time < 0:
		remaining_time = 0
	
	return true

func get_time_remaining_formatted() -> String:
	"""Retorna tempo restante formatado"""
	var minutes = int(remaining_time) / 60
	var seconds = int(remaining_time) % 60
	return "%02d:%02d" % [minutes, seconds]

func update_display(bar: ProgressBar, visible: bool):
	"""Atualiza o display da barra de incubação"""
	if bar:
		if visible:
			bar.value = total_time - remaining_time
			bar.visible = true
		else:
			bar.visible = false

func process_offline_time(time_offline: float):
	"""Processa tempo offline (ovo continua incubando)"""
	remaining_time -= time_offline
	if remaining_time < 0:
		remaining_time = 0

func get_save_data() -> Dictionary:
	"""Retorna dados para salvar"""
	return {
		"incubation_remaining_time": remaining_time,
		"incubation_last_pet_time": last_pet_time
	}

func load_save_data(save_data: Dictionary):
	"""Carrega dados salvos"""
	remaining_time = save_data.get("incubation_remaining_time", total_time)
	last_pet_time = save_data.get("incubation_last_pet_time", 0.0)
