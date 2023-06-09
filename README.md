# crusmake

Godot plugin with utilities for packaging Cruelty Squad mods. Includes support for including folders/files outside of the mod's folder, configurable file extension exclusions, and automatic `.import` dependency resolution.

![config-panel](./media/README-01.png)

To access configuration, configuration saving, and packaging for a mod, right click its container in the `Mod Export` panel:

![actions-context-menu](./media/README-context-menu.png)

Package building steps and errors will be displayed in a popup window and stdout:

![build-output](./media/README-build-output.png)

# Install

Clone/copy this repository into your project's addons folder in a folder named `crusmake`—e.g. `/path/to/project/addons/crusmake`, `res://addons/crusmake` in your Godot project.