extends Control

# SCRIPT PRINCIPAL DO TAMAGOTCHI
class_name TamagotchiController

# Estados do pet
enum PetState {
	EGG,      # Ovo
	HATCHED   # Chocado
}

var current_state: PetState = PetState.EGG

# Variáveis das necessidades
var hunger: float = 0.0
var happiness: float = 100.0

# Estatísticas de cuidado
var times_hungry: int = 0
var attention_given: int = 0
var visits_count: int = 0

# Sistema de evolução
var current_evolution: int = 0
var evolution_names: Array[String] = ["Bebê", "Jovem", "Adulto"]

# Controles para estatísticas
var hunger_check_threshold: float = 80.0
var last_hunger_state: bool = false

# Velocidades durante o jogo
var hunger_speed: float = 1.0
var happiness_speed: float = 0.5

# Velocidades offline (1/3 do valor normal)
var offline_hunger_speed: float = 0.33
var offline_happiness_speed: float = 0.17

# Arquivo de salvamento
var save_file_path = "user://tamagotchi_save.dat"

# Sistemas separados
var incubation_system: IncubationSystem
var dialog_system: DialogSystem

# Referências aos elementos da UI - CORRIGIDO
@onready var feed_button: TextureButton = $FeedButton
@onready var hunger_bar: ProgressBar = $HungerBar
@onready var happiness_bar: ProgressBar = $HappinessBar
@onready var pet_sprite: TextureButton = $PetSprite

# Elementos do sistema de diálogos - CORRIGIDO PARA CORRESPONDER À CENA
@onready var dialog_indicator: Button = $Button
@onready var dialog_popup: AcceptDialog = $AcceptDialog
@onready var dialog_label: RichTextLabel = $AcceptDialog/VBoxContainer/RichTextLabel

# Barra de incubação - usando a barra de felicidade como temporária
@onready var incubation_bar: ProgressBar = $HappinessBar

func _ready():
	print("=== INICIALIZANDO TAMAGOTCHI ===")
	
	# VERIFICAÇÃO DE SEGURANÇA - Verifica se todos os nós existem
	if not verify_ui_nodes():
		print("ERRO: Alguns nós da UI não foram encontrados!")
		return
	
	# Inicializa sistemas separados
	incubation_system = IncubationSystem.new()
	dialog_system = DialogSystem.new()
	
	# Conecta sistemas ao controlador principal
	incubation_system.connect_to_controller(self)
	dialog_system.connect_to_controller(self, dialog_indicator, dialog_popup, dialog_label)
	
	# Carrega o jogo salvo primeiro
	load_game()
	
	# Conta uma visita
	visits_count += 1
	
	print("Tamagotchi carregado!")
	print("Estado: ", "OVO" if current_state == PetState.EGG else "CHOCADO")
	if current_state == PetState.EGG:
		print("Tempo para chocar: ", incubation_system.get_time_remaining_formatted())
	else:
		print("Fome: ", hunger, " Felicidade: ", happiness)
	
	# Conecta botões
	setup_buttons()
	
	# Configura as barras
	setup_ui_bars()
	
	# Atualiza o display inicial
	update_display()
	
	# Verifica se pode evoluir (só se já chocou)
	if current_state == PetState.HATCHED:
		check_evolution()
	
	# Processa diálogos pendentes após um pequeno delay
	await get_tree().create_timer(2.0).timeout
	if dialog_system:
		dialog_system.process_dialog_queue()

# NOVA FUNÇÃO - Verifica se todos os nós necessários existem
func verify_ui_nodes() -> bool:
	var required_nodes = [
		{"path": "FeedButton", "node": null},
		{"path": "HungerBar", "node": null},
		{"path": "HappinessBar", "node": null},
		{"path": "PetSprite", "node": null},
		{"path": "Button", "node": null},
		{"path": "AcceptDialog", "node": null},
		{"path": "AcceptDialog/VBoxContainer/RichTextLabel", "node": null}
	]
	
	var all_found = true
	
	for node_info in required_nodes:
		var node = get_node_or_null(node_info.path)
		if not node:
			print("ERRO: Nó não encontrado: ", node_info.path)
			all_found = false
		else:
			print("✓ Nó encontrado: ", node_info.path)
	
	return all_found

func setup_buttons():
	"""Configura todos os botões"""
	if feed_button:
		if not feed_button.pressed.is_connected(_on_feed_button_pressed):
			feed_button.pressed.connect(_on_feed_button_pressed)
		setup_feed_button_effects()
	else:
		print("AVISO: feed_button não encontrado")
	
	if pet_sprite:
		if not pet_sprite.pressed.is_connected(_on_pet_clicked):
			pet_sprite.pressed.connect(_on_pet_clicked)
	else:
		print("AVISO: pet_sprite não encontrado")
	
	if dialog_indicator:
		if not dialog_indicator.pressed.is_connected(_on_dialog_indicator_pressed):
			dialog_indicator.pressed.connect(_on_dialog_indicator_pressed)
	else:
		print("AVISO: dialog_indicator não encontrado")

func setup_ui_bars():
	"""Configura todas as barras de progresso"""
	if hunger_bar:
		hunger_bar.min_value = 0
		hunger_bar.max_value = 100
		hunger_bar.value = hunger
	
	if happiness_bar:
		happiness_bar.min_value = 0
		happiness_bar.max_value = 100
		happiness_bar.value = happiness
	
	if incubation_bar and incubation_system:
		incubation_system.setup_incubation_bar(incubation_bar)

func _process(delta):
	if current_state == PetState.EGG:
		# Modo OVO: processa incubação
		if incubation_system:
			incubation_system.process(delta)
			
			# Verifica se chocou
			if incubation_system.should_hatch():
				hatch_egg()
	else:
		# Modo CHOCADO: sistema normal
		process_normal_pet(delta)
	
	# Processa sistema de diálogos
	if dialog_system:
		dialog_system.process(delta)
	
	# Atualiza as barras
	update_display()
	
	# Salva automaticamente a cada 5 segundos
	if int(Time.get_time_dict_from_system().second) % 5 == 0:
		save_game()

func process_normal_pet(delta):
	"""Processa as necessidades do pet chocado"""
	# Aumenta a fome
	hunger += hunger_speed * delta
	if hunger > 100:
		hunger = 100
	
	# Diminui a felicidade
	happiness -= happiness_speed * delta
	if happiness < 0:
		happiness = 0
	
	# Verifica se ficou com muita fome
	check_hunger_status()

func hatch_egg():
	"""Faz o ovo chocar"""
	current_state = PetState.HATCHED
	
	# Inicia com valores padrão para um bebê
	hunger = 20.0
	happiness = 80.0
	
	print("🐣 O OVO CHOCOU! Seu pet nasceu!")
	
	# Adiciona diálogo obrigatório de nascimento
	if dialog_system:
		dialog_system.add_dialog("Olá mundo! Eu nasci! 🐣 Obrigado por cuidar de mim quando eu era apenas um ovinho.", DialogSystem.DialogPriority.CRITICAL, "first_hatch")
	
	update_display()

func pet_egg():
	"""Acaricia o ovo"""
	if incubation_system and incubation_system.pet_egg():
		attention_given += 1
		print("🥰 Ovo acariciado! Tempo restante: ", incubation_system.get_time_remaining_formatted())

func update_display():
	"""Atualiza as barras que mostram o estado atual"""
	if current_state == PetState.EGG:
		# Modo ovo: mostra progresso da incubação
		if incubation_system:
			incubation_system.update_display(incubation_bar, true)
		
		# Esconde barras de fome e felicidade
		if hunger_bar:
			hunger_bar.visible = false
		if happiness_bar and happiness_bar != incubation_bar:  # Evita esconder se for a mesma barra
			happiness_bar.visible = false
		if feed_button:
			feed_button.visible = false
			
	else:
		# Modo chocado: mostra fome e felicidade
		if hunger_bar:
			hunger_bar.value = hunger
			hunger_bar.visible = true
		if happiness_bar:
			happiness_bar.value = happiness
			happiness_bar.visible = true
		if feed_button:
			feed_button.visible = true
		
		# Esconde barra de incubação
		if incubation_system:
			incubation_system.update_display(incubation_bar, false)
	
	# Atualiza indicador de diálogo
	if dialog_system:
		dialog_system.update_dialog_indicator()
	
	# Atualiza visual da evolução
	update_evolution_visual()

func feed():
	"""Alimentar o pet"""
	if current_state != PetState.HATCHED:
		return
		
	hunger -= 20
	if hunger < 0:
		hunger = 0
	
	attention_given += 1
	
	# Chance de diálogo
	if dialog_system and randf() < 0.1:
		dialog_system.add_dialog("Mmm, que delícia! Obrigado pela comida! 😋", DialogSystem.DialogPriority.LOW)
	
	print("Alimentado! Nova fome: ", int(hunger))
	check_evolution()
	save_game()

func play():
	"""Brincar com o pet"""
	if current_state != PetState.HATCHED:
		return
		
	happiness += 15
	if happiness > 100:
		happiness = 100
	
	attention_given += 1
	
	# Chance de diálogo
	if dialog_system and randf() < 0.1:
		dialog_system.add_dialog("Que divertido! Adoro brincar com você! 🎉", DialogSystem.DialogPriority.LOW)
	
	print("Brincando! Nova felicidade: ", int(happiness))
	check_evolution()
	save_game()

func check_hunger_status():
	"""Verifica se ficou faminto"""
	var is_very_hungry = hunger >= hunger_check_threshold
	
	if is_very_hungry and not last_hunger_state:
		times_hungry += 1
		print("Pet ficou faminto! Total: ", times_hungry)
	
	last_hunger_state = is_very_hungry

func check_evolution():
	"""Verifica se deve evoluir"""
	if current_state != PetState.HATCHED:
		return
		
	var new_evolution = calculate_evolution()
	
	if new_evolution > current_evolution:
		current_evolution = new_evolution
		print("🌟 EVOLUÇÃO! Agora é: ", evolution_names[current_evolution])
		
		# Gera diálogos de evolução
		if dialog_system:
			dialog_system.generate_evolution_dialogs(current_evolution, evolution_names)
		
		update_display()

func calculate_evolution() -> int:
	"""Calcula evolução baseada nas estatísticas"""
	if current_state != PetState.HATCHED:
		return 0
	
	if visits_count < 3 and attention_given < 5:
		return 0
	
	if visits_count >= 3 and attention_given >= 5 and times_hungry <= 3:
		return 1
	
	if times_hungry > 5:
		return 0
	
	return current_evolution

func update_evolution_visual():
	"""Atualiza visual baseado na evolução"""
	if not pet_sprite:
		return
	
	if current_state == PetState.EGG:
		# Verifica se o arquivo existe antes de carregar
		if ResourceLoader.exists("res://new folder/ovo 1.png"):
			pet_sprite.texture_normal = load("res://new folder/ovo 1.png")
		elif ResourceLoader.exists("res://new folder/ovo.png"):
			pet_sprite.texture_normal = load("res://new folder/ovo.png")
	else:
		match current_evolution:
			0, 1:  # Bebê e Jovem usam a mesma sprite
				if ResourceLoader.exists("res://new folder/lagartixa.png"):
					pet_sprite.texture_normal = load("res://new folder/lagartixa.png")

# === CALLBACKS DOS BOTÕES ===

func _on_feed_button_pressed():
	feed()

func _on_pet_clicked():
	if current_state == PetState.EGG:
		pet_egg()
	else:
		play()

func _on_dialog_indicator_pressed():
	if dialog_system:
		dialog_system.process_dialog_queue()

# === EFEITOS VISUAIS DO BOTÃO ===

func setup_feed_button_effects():
	if not feed_button:
		return
	
	# Desconecta sinais existentes para evitar duplicatas
	if feed_button.mouse_entered.is_connected(_on_feed_button_hover_enter):
		feed_button.mouse_entered.disconnect(_on_feed_button_hover_enter)
	if feed_button.mouse_exited.is_connected(_on_feed_button_hover_exit):
		feed_button.mouse_exited.disconnect(_on_feed_button_hover_exit)
	if feed_button.button_down.is_connected(_on_feed_button_pressed_visual):
		feed_button.button_down.disconnect(_on_feed_button_pressed_visual)
	if feed_button.button_up.is_connected(_on_feed_button_released_visual):
		feed_button.button_up.disconnect(_on_feed_button_released_visual)
	
	# Conecta novamente
	feed_button.mouse_entered.connect(_on_feed_button_hover_enter)
	feed_button.mouse_exited.connect(_on_feed_button_hover_exit)
	feed_button.button_down.connect(_on_feed_button_pressed_visual)
	feed_button.button_up.connect(_on_feed_button_released_visual)
	
	feed_button.pivot_offset = Vector2(feed_button.size.x / 2, feed_button.size.y / 2)

func _on_feed_button_hover_enter():
	if not feed_button:
		return
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(feed_button, "scale", Vector2(1.2, 1.2), 0.3)
	tween.parallel().tween_property(feed_button, "modulate", Color(1.3, 1.3, 1.3), 0.2)

func _on_feed_button_hover_exit():
	if not feed_button:
		return
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(feed_button, "scale", Vector2(1.0, 1.0), 0.2)
	tween.parallel().tween_property(feed_button, "modulate", Color.WHITE, 0.2)

func _on_feed_button_pressed_visual():
	if not feed_button:
		return
	var tween = create_tween()
	tween.tween_property(feed_button, "scale", Vector2(0.9, 0.9), 0.1)
	tween.parallel().tween_property(feed_button, "modulate", Color(0.7, 0.7, 0.7), 0.1)

func _on_feed_button_released_visual():
	if not feed_button:
		return
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	
	if feed_button.get_global_rect().has_point(feed_button.get_global_mouse_position()):
		tween.tween_property(feed_button, "scale", Vector2(1.2, 1.2), 0.15)
		tween.parallel().tween_property(feed_button, "modulate", Color(1.3, 1.3, 1.3), 0.15)
	else:
		tween.tween_property(feed_button, "scale", Vector2(1.0, 1.0), 0.15)
		tween.parallel().tween_property(feed_button, "modulate", Color.WHITE, 0.15)

# === SISTEMA DE SALVAMENTO ===

func save_game():
	"""Salva o estado atual do jogo"""
	var save_data = {
		"hunger": hunger,
		"happiness": happiness,
		"times_hungry": times_hungry,
		"attention_given": attention_given,
		"visits_count": visits_count,
		"current_evolution": current_evolution,
		"current_state": current_state,
		"last_save_time": Time.get_unix_time_from_system()
	}
	
	# Adiciona dados dos sistemas com verificação de segurança
	if incubation_system:
		save_data.merge(incubation_system.get_save_data())
	if dialog_system:
		save_data.merge(dialog_system.get_save_data())
	
	var file = FileAccess.open(save_file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()
		print("Jogo salvo com sucesso!")
	else:
		print("ERRO: Não foi possível salvar o jogo")

func load_game():
	"""Carrega o jogo salvo"""
	if not FileAccess.file_exists(save_file_path):
		print("Nenhum save encontrado. Começando com ovo!")
		return
	
	var file = FileAccess.open(save_file_path, FileAccess.READ)
	if not file:
		print("Erro ao abrir arquivo de save")
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result != OK:
		print("Erro ao ler save")
		return
	
	var save_data = json.data
	
	# Restaura valores básicos
	hunger = save_data.get("hunger", 0.0)
	happiness = save_data.get("happiness", 100.0)
	times_hungry = save_data.get("times_hungry", 0)
	attention_given = save_data.get("attention_given", 0)
	visits_count = save_data.get("visits_count", 0)
	current_evolution = save_data.get("current_evolution", 0)
	current_state = save_data.get("current_state", PetState.EGG)
	
	# Carrega dados dos sistemas com verificação de segurança
	if incubation_system:
		incubation_system.load_save_data(save_data)
	if dialog_system:
		dialog_system.load_save_data(save_data)
	
	# Processa tempo offline
	if save_data.has("last_save_time"):
		var current_time = Time.get_unix_time_from_system()
		var time_offline = current_time - save_data.last_save_time
		var hours_offline = time_offline / 3600.0
		
		print("Tempo offline: ", "%.1f" % hours_offline, " horas")
		
		# Processa sistemas offline
		if current_state == PetState.EGG:
			if incubation_system:
				incubation_system.process_offline_time(time_offline)
				if incubation_system.should_hatch():
					hatch_egg()
		else:
			# Aplica decay normal
			hunger += offline_hunger_speed * time_offline
			happiness -= offline_happiness_speed * time_offline
			
			if hunger > 100:
				hunger = 100
			if happiness < 0:
				happiness = 0
		
		# Processa diálogos offline
		if dialog_system:
			dialog_system.process_offline_dialogs(hours_offline, times_hungry, attention_given)
		
		print("Tempo offline processado!")
	
	print("Jogo carregado com sucesso!")

func _notification(what):
	"""Salva quando o jogo é fechado"""
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		get_tree().quit()
