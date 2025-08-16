# SISTEMA DE DIÁLOGOS DO TAMAGOTCHI
class_name DialogSystem
extends RefCounted

# Prioridades dos diálogos
enum DialogPriority {
	CRITICAL = 0,    # Evolução, primeira vez
	HIGH = 1,        # Ausência longa, negligência
	MEDIUM = 2,      # Ausência média, cuidados
	LOW = 3,         # Lore, conversa casual
	RANDOM = 4       # Diálogos aleatórios
}

# Sistema de diálogos
var dialog_queue: Array[Dictionary] = []
var shown_dialogs: Dictionary = {}
var dialog_shown_recently: bool = false
var dialog_delay_timer: float = 0.0
var dialog_delay_duration: float = 10.0  # 10 segundos entre diálogos
var dialog_chance_per_hour: float = 0.15  # 15% chance por hora offline

# Referências
var controller: TamagotchiController
var dialog_indicator: Button
var dialog_popup: AcceptDialog
var dialog_label: RichTextLabel

func connect_to_controller(main_controller: TamagotchiController, indicator: Button, popup: AcceptDialog, label: RichTextLabel):
	"""Conecta este sistema ao controlador e UI"""
	controller = main_controller
	dialog_indicator = indicator
	dialog_popup = popup
	dialog_label = label
	
	# Configura o indicador
	if dialog_indicator:
		dialog_indicator.text = "💬"
		dialog_indicator.visible = false

func process(delta: float):
	"""Processa o sistema de diálogos"""
	# Reduz o timer de delay entre diálogos
	if dialog_delay_timer > 0:
		dialog_delay_timer -= delta
		
		# Quando o delay acaba, processa próximo diálogo
		if dialog_delay_timer <= 0:
			dialog_shown_recently = false
			process_dialog_queue()

func add_dialog(text: String, priority: DialogPriority, dialog_id: String = ""):
	"""Adiciona um diálogo à fila"""
	var dialog_data = {
		"text": text,
		"priority": priority,
		"id": dialog_id,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	# Se tem ID e já foi mostrado, não adiciona novamente
	if dialog_id != "" and shown_dialogs.has(dialog_id):
		return
	
	dialog_queue.append(dialog_data)
	
	# Ordena a fila por prioridade
	dialog_queue.sort_custom(func(a, b): return a.priority < b.priority)
	
	print("Diálogo adicionado: ", text.substr(0, 30), "... [Prioridade: ", priority, "]")

func process_dialog_queue():
	"""Processa a fila de diálogos e mostra o próximo"""
	if dialog_queue.is_empty() or dialog_shown_recently:
		update_dialog_indicator()
		return
	
	# Pega o diálogo de maior prioridade
	var next_dialog = dialog_queue.pop_front()
	show_dialog(next_dialog)

func show_dialog(dialog_data: Dictionary):
	"""Mostra um diálogo na tela"""
	if not dialog_label or not dialog_popup:
		return
	
	# Marca como mostrado se tem ID
	if dialog_data.id != "":
		shown_dialogs[dialog_data.id] = true
	
	# Configura o texto do diálogo
	dialog_label.text = "[center]" + dialog_data.text + "[/center]"
	
	# Mostra o popup
	dialog_popup.popup_centered()
	dialog_popup.title = get_dialog_title(dialog_data.priority)
	
	# Marca que um diálogo foi mostrado recentemente
	dialog_shown_recently = true
	dialog_delay_timer = dialog_delay_duration
	
	print("Mostrando diálogo: ", dialog_data.text.substr(0, 50))
	
	update_dialog_indicator()

func get_dialog_title(priority: DialogPriority) -> String:
	"""Retorna o título da janela baseado na prioridade"""
	match priority:
		DialogPriority.CRITICAL:
			return "🌟 Momento Especial!"
		DialogPriority.HIGH:
			return "😢 Seu pet tem algo importante a dizer"
		DialogPriority.MEDIUM:
			return "😊 Seu pet quer conversar"
		DialogPriority.LOW:
			return "💭 Pensamentos do seu pet"
		DialogPriority.RANDOM:
			return "🎲 Seu pet está pensativo"
		_:
			return "💬 Conversa"

func update_dialog_indicator():
	"""Atualiza a visibilidade do indicador de diálogo"""
	if not dialog_indicator:
		return
	
	dialog_indicator.visible = not dialog_queue.is_empty()
	
	if not dialog_queue.is_empty():
		# Muda a cor baseado na prioridade do próximo diálogo
		var next_priority = dialog_queue[0].priority
		match next_priority:
			DialogPriority.CRITICAL:
				dialog_indicator.modulate = Color.GOLD
			DialogPriority.HIGH:
				dialog_indicator.modulate = Color.ORANGE_RED
			DialogPriority.MEDIUM:
				dialog_indicator.modulate = Color.SKY_BLUE
			_:
				dialog_indicator.modulate = Color.WHITE

# === GERADORES DE DIÁLOGOS ===

func generate_absence_dialogs(hours_absent: float):
	"""Gera diálogos baseados no tempo de ausência"""
	if hours_absent < 1:
		return
	
	if hours_absent >= 24:  # Mais de 1 dia
		add_dialog("Você sumiu por tanto tempo... Pensei que tinha me esquecido para sempre! 😢 Por favor, não me abandone assim de novo.", DialogPriority.HIGH, "absence_day_" + str(int(hours_absent/24)))
	elif hours_absent >= 8:  # Mais de 8 horas
		add_dialog("Onde você estava? Fiquei te esperando por horas e horas... Senti sua falta! 😟", DialogPriority.HIGH, "absence_long_" + str(int(hours_absent)))
	elif hours_absent >= 3:  # Mais de 3 horas
		add_dialog("Que bom que voltou! Estava começando a ficar preocupado... 😌", DialogPriority.MEDIUM, "absence_medium_" + str(int(hours_absent)))

func generate_care_dialogs(attention_given: int, times_hungry: int):
	"""Gera diálogos baseados nos cuidados recebidos"""
	if attention_given >= 20:
		add_dialog("Você cuida muito bem de mim! Me sinto tão amado e feliz! ❤️", DialogPriority.MEDIUM, "care_excellent")
	elif attention_given >= 10:
		add_dialog("Obrigado por cuidar de mim! Você é um ótimo cuidador! 😊", DialogPriority.MEDIUM, "care_good")
	
	if times_hungry >= 5:
		add_dialog("Às vezes sinto muita fome... Você poderia me alimentar mais vezes? 🥺", DialogPriority.HIGH, "neglect_hunger")

func generate_evolution_dialogs(evolution_level: int, evolution_names: Array[String]):
	"""Gera diálogos obrigatórios de evolução"""
	match evolution_level:
		1:
			add_dialog("Wow! Eu cresci! Agora sou mais forte e inteligente! 🌟 Obrigado por me ajudar a evoluir!", DialogPriority.CRITICAL, "evolution_young")
		2:
			add_dialog("Finalmente me tornei adulto! 🎉 Isso é tudo graças aos seus cuidados. Vamos continuar crescendo juntos!", DialogPriority.CRITICAL, "evolution_adult")

func generate_random_dialogs():
	"""Gera diálogos aleatórios de lore e conversa"""
	var random_dialogs = [
		"Você sabia que quando eu era ovo, eu podia sentir seus carinhos? Era tão quentinho... ☺️",
		"Às vezes me pergunto como é o mundo lá fora. Você poderia me contar sobre ele? 🌍",
		"Tenho sonhado com lugares coloridos e cheios de outros pets como eu! 🌈",
		"Sabe o que mais gosto? Quando você clica em mim! É como um abraço digital! 🤗",
		"Eu me pergunto... será que existem outros como eu por aí? 🤔",
		"Quando cresço, sinto que entendo melhor o mundo ao meu redor! 📚",
		"Obrigado por dedicar seu tempo para ficar comigo! Isso significa muito! 💕"
	]
	
	var random_index = randi() % random_dialogs.size()
	var dialog_text = random_dialogs[random_index]
	add_dialog(dialog_text, DialogPriority.RANDOM, "random_" + str(random_index) + "_v" + str(Time.get_unix_time_from_system()))

func process_offline_dialogs(hours_offline: float, times_hungry: int, attention_given: int):
	"""Processa diálogos que podem ter sido gerados enquanto offline"""
	# Gera diálogos de ausência (sempre prioridade)
	generate_absence_dialogs(hours_offline)
	
	# Gera diálogos de cuidado baseado no estado atual
	generate_care_dialogs(attention_given, times_hungry)
	
	# Chance de diálogos aleatórios baseado no tempo offline
	var dialog_attempts = int(hours_offline * dialog_chance_per_hour)
	
	for i in dialog_attempts:
		if randf() < dialog_chance_per_hour:  # 15% chance por tentativa
			generate_random_dialogs()
			break  # Só gera um diálogo aleatório por sessão offline

func get_save_data() -> Dictionary:
	"""Retorna dados para salvar"""
	return {
		"dialog_queue": dialog_queue,
		"shown_dialogs": shown_dialogs,
		"dialog_delay_timer": dialog_delay_timer,
		"dialog_shown_recently": dialog_shown_recently
	}

func load_save_data(save_data: Dictionary):
	"""Carrega dados salvos"""
	dialog_queue = save_data.get("dialog_queue", [])
	shown_dialogs = save_data.get("shown_dialogs", {})
	dialog_delay_timer = save_data.get("dialog_delay_timer", 0.0)
	dialog_shown_recently = save_data.get("dialog_shown_recently", false)
