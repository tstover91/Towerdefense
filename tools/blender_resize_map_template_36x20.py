import bpy
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "blender_assets" / "blank 30x20 map template.blend"
OUTPUT = ROOT / "blender_assets" / "blank 36x20 map template.blend"
PREVIEW = ROOT / "blender_assets" / "blank 36x20 map template preview.png"

WIDTH = 36.0
HEIGHT = 20.0
HALF_W = WIDTH / 2.0
HALF_H = HEIGHT / 2.0


def add_line_spline(curve, a, b):
    spline = curve.splines.new("POLY")
    spline.points.add(1)
    spline.points[0].co = (*a, 1.0)
    spline.points[1].co = (*b, 1.0)


def rebuild_grid(obj):
    curve = obj.data
    curve.splines.clear()
    for x in range(-int(HALF_W), int(HALF_W) + 1):
        add_line_spline(curve, (x, -HALF_H, 0.0), (x, HALF_H, 0.0))
    for y in range(-int(HALF_H), int(HALF_H) + 1):
        add_line_spline(curve, (-HALF_W, y, 0.0), (HALF_W, y, 0.0))


def rebuild_boundary(obj):
    curve = obj.data
    curve.splines.clear()
    add_line_spline(curve, (-HALF_W, -HALF_H, 0.0), (HALF_W, -HALF_H, 0.0))
    add_line_spline(curve, (HALF_W, -HALF_H, 0.0), (HALF_W, HALF_H, 0.0))
    add_line_spline(curve, (HALF_W, HALF_H, 0.0), (-HALF_W, HALF_H, 0.0))
    add_line_spline(curve, (-HALF_W, HALF_H, 0.0), (-HALF_W, -HALF_H, 0.0))


if bpy.data.filepath != str(SOURCE):
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))

grid = bpy.data.objects["TILE_GRID_GUIDE"]
boundary = bpy.data.objects["MAP_BOUNDARY_GUIDE"]
ground = bpy.data.objects["EDITABLE_GROUND_30x20"]
path = bpy.data.objects["EDIT_THIS_ENEMY_PATH"]
entry = bpy.data.objects["ENEMY_ENTRY_HELPER"]
exit_marker = bpy.data.objects["ENEMY_EXIT_HELPER"]
export_camera = bpy.data.objects["EXPORT_CAMERA_960x648"]
preview_camera = bpy.data.objects["DECORATION_PREVIEW_CAMERA"]

rebuild_grid(grid)
rebuild_boundary(boundary)

ground.name = "EDITABLE_GROUND_36x20"
ground.dimensions.x = WIDTH

# Keep the starter path centered and extend it to the new map edges.
spline = path.data.splines[0]
if len(spline.bezier_points) == 2:
    spline.bezier_points[0].co.x = -HALF_W
    spline.bezier_points[1].co.x = HALF_W
elif len(spline.points) == 2:
    spline.points[0].co.x = -HALF_W
    spline.points[1].co.x = HALF_W

entry.location.x = -HALF_W
exit_marker.location.x = HALF_W

# 1152:640 exactly matches the new 36:20 map ratio and retains the original
# template's 32 pixels per tile.
export_camera.name = "EXPORT_CAMERA_1152x640"
export_camera.data.ortho_scale = 20.25
bpy.context.scene.camera = export_camera
bpy.context.scene.render.resolution_x = 1152
bpy.context.scene.render.resolution_y = 640
bpy.context.scene.render.resolution_percentage = 100
bpy.context.scene.render.image_settings.file_format = "PNG"
bpy.context.scene.render.filepath = str(PREVIEW)

# Widen the editor preview framing without changing its viewing angle.
preview_camera.data.ortho_scale = 29.0

bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT))
bpy.ops.render.render(write_still=True)
print(f"Saved {OUTPUT}")
print(f"Rendered {PREVIEW}")
