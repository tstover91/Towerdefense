import bpy
import math
from pathlib import Path
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[1]
OUT_BLEND = ROOT / "blender_assets" / "farm_barn_simple.blend"
OUT_PREVIEW = ROOT / "blender_assets" / "farm_barn_simple_preview.png"


def material(name, color):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.9
    return mat


def box(name, location, scale, mat, rotation=(0.0, 0.0, 0.0), bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.scale = (scale[0] / 2, scale[1] / 2, scale[2] / 2)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    if bevel:
        mod = obj.modifiers.new("Small edge bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 1
    return obj


def gable_wall(name, width, depth, eave_z, ridge_z, mat):
    x = width / 2
    y = depth / 2
    verts = [
        (-x, -y, 0), (x, -y, 0), (x, -y, eave_z), (0, -y, ridge_z), (-x, -y, eave_z),
        (-x, y, 0), (x, y, 0), (x, y, eave_z), (0, y, ridge_z), (-x, y, eave_z),
    ]
    faces = [
        (0, 1, 2, 3, 4), (9, 8, 7, 6, 5),
        (0, 5, 6, 1), (1, 6, 7, 2), (2, 7, 8, 3),
        (3, 8, 9, 4), (4, 9, 5, 0),
    ]
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def beam_between(name, a, b, thickness, depth, mat):
    a = Vector(a)
    b = Vector(b)
    delta = b - a
    obj = box(name, (a + b) / 2, (thickness, depth, delta.length), mat)
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(delta.normalized())
    return obj


def pyramid_roof(name, location, radius, height, mat):
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=radius, radius2=0, depth=height, location=location, rotation=(0, 0, math.radians(45)))
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
    pass

red = material("Barn Red", (0.565, 0.063, 0.033))
cream = material("Cream Trim", (0.82, 0.66, 0.38))
charcoal = material("Outline Charcoal", (0.009, 0.009, 0.013))
brown = material("Door Brown", (0.25, 0.10, 0.035))
stone = material("Foundation Stone", (0.25, 0.25, 0.22))
grass = material("Preview Grass", (0.19, 0.48, 0.055))

# Main shell and roof.
gable_wall("Barn_Main_Shell", 8.0, 6.0, 4.4, 6.9, red)
roof_angle = math.atan2(2.8, 4.35)
roof_length = math.sqrt(4.35 ** 2 + 2.8 ** 2)
box("Roof_Left", (-2.08, 0, 5.72), (roof_length, 6.6, 0.28), charcoal, (0, -roof_angle, 0))
box("Roof_Right", (2.08, 0, 5.72), (roof_length, 6.6, 0.28), charcoal, (0, roof_angle, 0))

# Front double doors and simple cream framing.
front_y = -3.03
box("Door_Left", (-1.05, front_y, 1.55), (1.9, 0.12, 3.1), brown)
box("Door_Right", (1.05, front_y, 1.55), (1.9, 0.12, 3.1), brown)
box("Door_Frame_Left", (-2.08, front_y - 0.02, 1.58), (0.22, 0.16, 3.35), cream)
box("Door_Frame_Center", (0, front_y - 0.02, 1.58), (0.22, 0.16, 3.35), cream)
box("Door_Frame_Right", (2.08, front_y - 0.02, 1.58), (0.22, 0.16, 3.35), cream)
box("Door_Header", (0, front_y - 0.02, 3.18), (4.38, 0.16, 0.25), cream)
box("Door_Sill", (0, front_y - 0.02, 0.10), (4.38, 0.16, 0.20), cream)
beam_between("Door_Left_Brace_A", (-1.88, front_y - 0.11, 0.25), (-0.20, front_y - 0.11, 2.95), 0.18, 0.12, cream)
beam_between("Door_Left_Brace_B", (-0.20, front_y - 0.12, 0.25), (-1.88, front_y - 0.12, 2.95), 0.18, 0.12, cream)
beam_between("Door_Right_Brace_A", (0.20, front_y - 0.11, 0.25), (1.88, front_y - 0.11, 2.95), 0.18, 0.12, cream)
beam_between("Door_Right_Brace_B", (1.88, front_y - 0.12, 0.25), (0.20, front_y - 0.12, 2.95), 0.18, 0.12, cream)

# Hayloft opening.
box("Hayloft_Dark", (0, front_y - 0.03, 4.67), (1.35, 0.14, 1.25), charcoal)
box("Hayloft_Top", (0, front_y - 0.12, 5.35), (1.65, 0.18, 0.20), cream)
box("Hayloft_Bottom", (0, front_y - 0.12, 3.99), (1.65, 0.18, 0.20), cream)
box("Hayloft_Left", (-0.72, front_y - 0.12, 4.67), (0.20, 0.18, 1.55), cream)
box("Hayloft_Right", (0.72, front_y - 0.12, 4.67), (0.20, 0.18, 1.55), cream)

# Lean-to on the left side.
box("LeanTo_Wall", (-5.05, 0.55, 1.55), (2.1, 4.5, 3.1), red)
lean_angle = math.radians(-14)
box("LeanTo_Roof", (-5.05, 0.55, 3.43), (2.65, 4.9, 0.22), charcoal, (0, lean_angle, 0))
box("LeanTo_Post_Front", (-6.0, -1.45, 1.45), (0.22, 0.22, 2.9), cream)
box("LeanTo_Post_Back", (-6.0, 2.55, 1.45), (0.22, 0.22, 2.9), cream)

# Cupola and simple weather vane silhouette.
box("Cupola_Base", (0, 0, 7.18), (1.25, 1.25, 1.15), red)
box("Cupola_Trim_Lower", (0, 0, 6.64), (1.42, 1.42, 0.16), cream)
box("Cupola_Trim_Upper", (0, 0, 7.75), (1.42, 1.42, 0.16), cream)
pyramid_roof("Cupola_Roof", (0, 0, 8.18), 1.02, 0.82, charcoal)
box("WeatherVane_Post", (0, 0, 9.05), (0.09, 0.09, 1.10), charcoal)
box("WeatherVane_Bar", (0, 0, 9.28), (1.05, 0.08, 0.09), charcoal)
box("WeatherVane_Arrow", (0.56, 0, 9.28), (0.34, 0.09, 0.20), charcoal, (0, math.radians(45), 0))

# Chunky foundation blocks.
for x in (-3.75, 3.75, -6.0):
    box(f"Foundation_{x}", (x, -2.7 if x != -6.0 else -1.45, 0.18), (0.55, 0.55, 0.36), stone)

# Organize the asset and create an origin marker at ground center.
barn_collection = bpy.data.collections.new("FARM_BARN_SIMPLE")
bpy.context.scene.collection.children.link(barn_collection)
for obj in list(bpy.context.scene.collection.objects):
    if obj.type == "MESH" and obj.name != "Preview_Ground":
        for col in list(obj.users_collection):
            col.objects.unlink(obj)
        barn_collection.objects.link(obj)

box("Preview_Ground", (0, 0, -0.16), (18, 13, 0.25), grass)

# Preview camera and lighting; these do not affect appended barn geometry.
bpy.ops.object.camera_add(location=(15, -19, 13))
camera = bpy.context.object
camera.name = "Preview_Camera"
bpy.context.scene.camera = camera
direction = Vector((0, 0, 3.8)) - camera.location
camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
camera.data.type = "ORTHO"
camera.data.ortho_scale = 15.5

bpy.ops.object.light_add(type="SUN", location=(-6, -8, 14))
sun = bpy.context.object
sun.name = "Preview_Sun"
sun.data.energy = 2.2
sun.rotation_euler = (math.radians(28), math.radians(-22), math.radians(-35))

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 1000
scene.render.resolution_y = 760
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = str(OUT_PREVIEW)
scene.world.color = (0.055, 0.055, 0.055)
scene.view_settings.look = "AgX - Medium High Contrast"
scene.render.film_transparent = False

OUT_BLEND.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT_BLEND))
bpy.ops.render.render(write_still=True)
print(f"Saved {OUT_BLEND}")
print(f"Rendered {OUT_PREVIEW}")
