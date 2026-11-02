extends Node
## 全局提示：任何系统都可以 Messages.say("...")，由 HUD 统一显示。

signal message(text: String)


func say(text: String) -> void:
	if text == "":
		return
	message.emit(text)
