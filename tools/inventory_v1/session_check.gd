extends SceneTree
var failures:=0
var checks:=0
class ExitProbe extends Node:
 var quitting:=false
 var saved:=false
 var failed:=""
 func quit_failed(message:String):failed=message;quitting=false
 func quit_saved():saved=true;quitting=false
func _initialize():call_deferred("run")
func check(value:bool,message:String):
 checks+=1
 if not value:failures+=1;push_error("FAIL: "+message)
 else:print("PASS: "+message)
func buttons(node:Node) -> Array[String]:
 var result:Array[String]=[]
 for button in node.find_children("*","Button",true,false):result.append(button.text)
 return result
func run():
 var desktop:bool=ResourceLoader.exists("res://prototype/apartment.tscn")
 var game=load("res://prototype/apartment.tscn" if desktop else "res://scenes/main.tscn").instantiate();root.add_child(game)
 for i in 12:await process_frame
 game.set_process(false);game.neighborhood.set_process(false)
 for timer in game.find_children("*","Timer",true,false):timer.stop()
 game.inventory_system.guide.skip();game.tutorial_panel.hide();game.daily_report_panel.hide();game.daily_report_pending=false
 game._resume_gameplay();game._pause_gameplay()
 var inv:Node=game.inventory_system
 var menu:Node=inv.session_menu
 check(buttons(menu.body)==["RESUME GAME","SETTINGS","HELP","SAVE & QUIT"],"Pause presents Resume, Settings, Help and Save & Quit in order")
 menu.show_page("settings")
 check("ACCOUNT SETTINGS" in buttons(menu.body),"Account settings are available from Pause")
 if desktop:check("CONTROLS & DISPLAY" in buttons(menu.body),"Desktop settings retain controller and display controls")
 menu.show_page("help")
 check("START GUIDE" in buttons(menu.body),"Pause Help offers the version-specific tutorial")
 menu._process(0)
 check(menu.panel.get_global_rect().size.y<=game.get_viewport().get_visible_rect().size.y,"Scrollable Help stays inside viewport")
 menu.show_page("home");game._open_phone_app("home")
 check(not "SETTINGS" in buttons(game.phone_panel) and not "Settings" in buttons(game.phone_panel),"Phone no longer duplicates settings navigation")
 game.phone_open=false;game.phone_panel.hide()
 var probe:=ExitProbe.new();root.add_child(probe);inv.session_menu=probe
 game.cash=1234
 await game._phone_safe_quit()
 check(probe.saved and game.last_save_ok,"Save and Quit verifies a fresh successful save before exiting")
 var saved:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH))
 check(int(saved.cash)==1234,"Quit saves current career data")
 probe.saved=false;game.reset_in_progress=true
 await game._phone_safe_quit()
 check(not probe.saved and not probe.failed.is_empty(),"Failed save keeps the game open and reports the problem")
 game.reset_in_progress=false;inv.session_menu=menu
 if desktop:
  check(game.status_label.anchor_top==0 and game.status_label.offset_top>=0 and game.status_label.has_theme_stylebox_override("normal"),"Desktop messages use a top-screen backing bubble")
  check(game.fp_prompt.has_theme_stylebox_override("normal") and game.fp_prompt.offset_top==inv.nearby_button.offset_top,"Desktop native and inventory prompts share style and bottom-center position")
 else:
  inv._process(0)
  check(game.neighborhood.action.has_meta("modern_interaction"),"Mobile native interactions receive shared modern styling")
  check(game.neighborhood.action.anchor_right==1 and inv.nearby_button.anchor_right==1,"Both mobile prompt producers remain bottom-right")
 game.queue_free();probe.queue_free();await process_frame
 print("SESSION_UI_TEST_RESULT: ","PASS" if failures==0 else "FAIL"," checks=",checks," failures=",failures)
 quit(0 if failures==0 else 1)
