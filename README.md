# 🦥 Godot 3D - Drag & Drop

[Overview](#overview-dart) /
[Features](#features) /
[Demo](https://github.com/JustKesha/godot-dragndrop-demo) /
[Quick start](#quick-start-ocean) /
[Перевести на русский ?](PROCHTI.md)

## Overview :dart:

This is a powerful and highly customizable script for Godot 4 and higher written in GDScript that implements 3D drag and drop mechanics using RayCast3D node, feel free to use it for your projects!

### Features
1. ___Physics based___ and normal drag
1. ___Chargeable___ and basic ___throws___
1. ___Zoom___ in and out
1. ___Angle stabilisation___
1. Jam handling (5 modes)
1. Hold & toggle modes

Here's a preview GIF from the [demo project](https://github.com/JustKesha/godot-dragndrop-demo):

<img alt="Preview GIF" src="https://media1.tenor.com/m/7aULtCVOahQAAAAd/godot-godot3d.gif" width="500px" />

There's also:

- Support for both **static and rigid** objects
- **Single key controls** option (for all actions)
- **47 parameters** nicely organised in inspector tab (with docstring)
- **12 signals** for you to use in other scripts

## Quick start :ocean:

> [!TIP]
> You can download and try out a demo project from [this repository](https://github.com/JustKesha/godot-dragndrop-demo)

> [!NOTE]
> Godot 4 & higher is recommended (tested with 4.5)

Adding to your project:
1. Download [drag_and_drop.gd](./source/drag_and_drop.gd) and add it to your project
1. Create a `RayCast3D` node somewhere on your character
1. Drag and drop the script onto your `RayCast3D` node
1. Make sure the `RayCast3D` is always facing the same direction as your character
1. Create the following input actions - `drag` `drop` `throw` `zoom_in` `zoom_out` in<br>
Project → Project Settings → Input Map<br>
(all names and other values can be changed in Inspector)
1. Choose the objects you want to be draggable and add metadata of type `bool` named "`draggable`" to them, toggle each on
1. Start your game
