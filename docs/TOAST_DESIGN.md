# Notification toast

Open `res://Scene/UI/toast_ui.tscn` to edit the native Godot UI. PanelContainer/Layout contains the small wooden Notification heading and Paper/ScrollContainer/ToastLabel. Local Theme and StyleBox resources reuse the existing wood, button, and parchment textures. The root is still ToastUI, so the existing persistent scene and item-acquisition notice reference remain valid.

The card is centered near the top of the safe screen area, capped at 640 pixels wide, with safe-area margins on mobile. Short text sizes the card to its content. Long text has a bounded vertical reading area and visible scrolling; replacement messages reset to the top and shrink the card when appropriate. Body text uses the existing bundled font family, smooth rendering, dark-brown ink, and increased line spacing.

The toast has no fullscreen shade or dismiss button and never changes focus or pauses gameplay. Short toasts ignore pointer input. Only overflowing text accepts scrolling. A high visual z-index and front sibling order keep it above later UI panels while allowing its scroll area to receive input.

UIManager and every caller remain unchanged. Messages appear verbatim for the duration requested by the caller, including existing DDA explanation-duration adjustments. A native one-shot DisplayTimer replaces per-request timer callbacks: a new request restarts this single timer, so an earlier message cannot hide a newer one. Nonpositive durations expire on the next timer tick. No queue or inferred success/error categories were added. ItemRewardToast continues waiting while the generic toast is visible.

Six GUT tests cover signal-driven messages, replacement deadlines, pause-safe expiry, short-message input pass-through, focus preservation and overlay order, long-to-short scroll reset, viewport bounds, and the existing item-notification handoff. Desktop, small-landscape, and phone renders were inspected. Physical Android touch and safe areas remain manual checks.
