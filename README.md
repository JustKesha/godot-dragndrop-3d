# 🦥 Godot 3D - Drag & Drop

[Перевести на русский ?](PROCHTI.md)

1. [Overview](#overview-dart)
1. [Features](#features)
1. [Showcase](README.md) `Coming`
1. [Demo](README.md) `Coming`
1. [Quick start](#quick-start-ocean)

## Overview :dart:

This is a powerful and highly customizable script for Godot 4 and higher written in GDScript that implements 3D drag and drop mechanics using RayCast3D node

### Features
1. Physics based drag & drop
1. Hold & toggle modes
1. Chargeable and basic throws
1. Zoom in and out
1. Angle stabilisation

There's also:

- Support for both **static and rigid** objects
- **Jam handling** (5 modes)
- **Single key controls** for all drag, drop and throw actions are possible!
- **47 parameters** nicely organised right in your inspector (with docstring explanations)
- **12 signals** for you to use in other scripts

## Quick start :ocean:

> [!IMPORTANT]
> Requires Godot 4 and higher. Tested with 4.5.

Adding to your project:
1. Download [drag_and_drop.gd](./source/drag_and_drop.gd) and add it to your project
1. Attach this script to any RayCast3D node
1. Make sure the raycast is always facing the same direction as your character's "face"
1. Create new actions inside the input map for the drag and drop mechanics<br>
Project → Project Settings → Input Map<br>

> [!TIP]
> You can name your actions as follows to skip the step number 5<br>
> `drag` `drop` `throw` `zoom_in` `zoom_out`

5. Pass your action names to the script<br>
    - Through the inspector when selecting your raycast<br>
    DragAndDrop3D → Controls Category →  Controls
    - Or directly inside the script
5. Choose the objects you want to be draggable and add a metadata of type bool named "draggable" to each (name can be changed through the inspector)
5. Start your scene
