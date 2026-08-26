import math
from pathlib import Path

import bpy


OUTPUT = Path(
    r"C:\Users\poops\OneDrive\Desktop\Towerdefense\blender_assets\renders\farm_map_clean_topdown_source.png"
)

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 1536
scene.render.resolution_y = 1536
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.filepath = str(OUTPUT)
scene.render.film_transparent = False
scene.render.use_freestyle = False

scene.view_settings.view_transform = "AgX"
scene.view_settings.look = "AgX - Base Contrast"
scene.view_settings.exposure = 0.0
scene.view_settings.gamma = 1.0

camera = bpy.data.objects.get("EXPORT_CAMERA_960x648") or scene.camera
scene.camera = camera
camera.location = (0.0, 0.0, 35.0)
camera.rotation_euler = (0.0, 0.0, 0.0)
camera.data.type = "ORTHO"
camera.data.ortho_scale = 32.0

for guide_name in (
    "TILE_GRID_GUIDE",
    "MAP_BOUNDARY_GUIDE",
    "EDIT_THIS_ENEMY_PATH",
):
    guide = bpy.data.objects.get(guide_name)
    if guide is not None:
        guide.hide_render = True

world = scene.world
world.use_nodes = True
background = world.node_tree.nodes.get("Background")
background.inputs["Color"].default_value = (0.055, 0.065, 0.085, 1.0)
background.inputs["Strength"].default_value = 0.7

for obj in bpy.data.objects:
    if obj.type == "LIGHT":
        obj.hide_render = obj.data.type != "SUN"

sun = next((obj for obj in bpy.data.objects
            if obj.type == "LIGHT" and obj.data.type == "SUN"), None)
if sun is not None:
    sun.hide_render = False
    sun.data.energy = 1.75
    sun.data.angle = math.radians(18.0)
    sun.data.use_shadow = False
    sun.rotation_euler = (
        math.radians(28.0),
        math.radians(-22.0),
        math.radians(-35.0),
    )

OUTPUT.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.render.render(write_still=True)
print(f"CLEAN_RENDER={OUTPUT}")
