extends RefCounted
## Royal Chinese palette for runtime UI controls.
static var arabic_font: Font = load("res://assets/fonts/NotoSansArabic-Bold.ttf") if ResourceLoader.exists("res://assets/fonts/NotoSansArabic-Bold.ttf") else null

static func apply(control: Control) -> void:
 if arabic_font != null:
  control.add_theme_font_override("font",arabic_font)
  control.add_theme_font_size_override("font_size",16)
 var panel:=StyleBoxFlat.new(); panel.bg_color=Color("#1A0D0B")
 panel.border_color=Color("#D4AF37"); panel.set_border_width_all(2); panel.set_corner_radius_all(5)
 panel.content_margin_left=10; panel.content_margin_right=10; panel.content_margin_top=8; panel.content_margin_bottom=8
 var hover:=panel.duplicate() as StyleBoxFlat; hover.bg_color=Color("#35120f"); hover.border_color=Color("#f2d477")
 for kind in ["Panel","PanelContainer","PopupPanel"]:
  control.add_theme_stylebox_override(kind,panel)
 control.add_theme_stylebox_override("normal",panel)
 control.add_theme_stylebox_override("hover",hover)
 control.add_theme_color_override("font_color",Color("#f5e8c8"))
 control.add_theme_color_override("font_hover_color",Color("#D4AF37"))

static func apply_tree(root: Node) -> void:
 for child in root.get_children():
  if child is Control:
   apply(child)
  apply_tree(child)
