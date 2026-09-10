extends Control
class_name ToastUI
## ToastUI
##
## Actually renders what UIManager.show_notification() requests. This did
## not exist before - show_notification() only ever emitted
## EventBus.ui_notification_requested with no listener anywhere in the
## project, meaning every "toast" referenced in FishingUI's denial/result
## messages and FishingRodComponent's "no rod" message was firing
## correctly but never visible on screen. This script closes that gap.
##
## Deliberately simple: one label, fades in on request, hides after
## `duration` seconds. If a new notification arrives while one is still
## showing, it immediately replaces the old one (no queue) - a token
## counter prevents the OLD notification's hide-timer from incorrectly
## hiding the NEW notification early. A proper queue (showing multiple
## notifications in sequence rather than replacing) is reasonable future
## polish, not built here.
##
## SETUP: attach to a Control root. Requires a Label named "ToastLabel",
## marked "Access as Unique Name". Add this scene to your persistent UI
## layer (Main.tscn's CanvasLayer), same as FishingUI and DialogueUI.

@onready var toast_label: Label = %ToastLabel

var _current_token: int = 0


func _ready() -> void:
	# Same reasoning as FishingUI - toasts should be readable even if
	# something in the future fires one while gameplay happens to be
	# paused, so this isn't silently frozen along with everything else.
	process_mode = Node.PROCESS_MODE_ALWAYS

	visible = false
	EventBus.ui_notification_requested.connect(_on_notification_requested)


func _on_notification_requested(message: String, duration: float) -> void:
	_current_token += 1
	var this_token := _current_token

	toast_label.text = message
	visible = true

	await get_tree().create_timer(duration).timeout

	# Only hide if nothing newer has arrived since this timer started -
	# otherwise this would incorrectly cut off a message that replaced us.
	if this_token == _current_token:
		visible = false
