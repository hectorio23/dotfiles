from settings.widgets import widget_defaults, extension_defaults
from settings.layouts import layouts, floating_layout
from settings.screens import screens
from settings.path import qtile_path
from settings.keys import mod, keys
from settings.groups import groups
from settings.mouse import mouse
from libqtile import hook

from os import path
import subprocess


@hook.subscribe.startup_once
def autostart():
    subprocess.call([path.join(qtile_path, 'autostart.sh')])

# Some configuration variables
auto_fullscreen = True
bring_front_click = False
cursor_warp = True
dgroups_key_binder = None
dgroups_app_rules = []

