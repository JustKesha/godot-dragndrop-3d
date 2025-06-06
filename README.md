# 🦥 Godot 3D - Drag & Drop

[Перевести на русский ?](PROCHTI.md)

1. [Overview](#overview-dart)
1. [Features](#features)
1. [Demo](#demo)
1. [Quick start](#quick-start-ocean)

## Overview :dart:

This is a powerful and highly customizable script for Godot 4 and higher written in GDScript that implements 3D drag and drop mechanics using RayCast3D node

### Features
1. **Physics based** drag (2 modes)
1. **Hold & toggle** modes
1. **Chargeable** and basic **throws**
1. **Zoom** in and out
1. Angle **stabilisation**
1. **Jam handling** (5 modes)

There's also:

- Support for both **static and rigid** objects
- **Single key controls** option (for all actions)
- **47 parameters** nicely organised in inspector tab (with docstring)
- **12 signals** for you to use in other scripts

### Demo

You can install a demo project from [this repository](https://github.com/JustKesha/godot-dragndrop-demo)

![](https://cdn.discordapp.com/attachments/1229518358022717594/1379718800206860318/ezgif.com-optimize_1.gif?ex=684142c3&is=683ff143&hm=718731ad846f24a569ad41064518ee7e72c826f8bff4377c9394a887b04f7219&)

## Quick start :ocean:

> [!IMPORTANT]
> Requires Godot 4 and higher. Tested with 4.5.

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
