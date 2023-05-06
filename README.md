# crusmake

Godot plugin with utilities for packaging Cruelty Squad mods. Includes support for including folders/files outside of the mod's folder, as well as configurable file extension exclusions.

![config-panel](./media/README-01.png)

To access configuration, configuration saving, and packaging for a mod, right click its container in the `Mod Export` panel:

![actions-context-menu](./media/README-context-menu.png)

Package building steps and errors will be displayed in a popup window as well as Godot stdout:

![build-output](./media/README-build-output.png)

# Install

Clone/copy this repository into your project's addons folder in a folder named `crusmake`—e.g. `/path/to/project/addons/crusmake`, the Godot path `res://addons/crusmake`.