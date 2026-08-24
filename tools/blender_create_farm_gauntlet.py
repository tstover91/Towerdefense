import bpy
import math
from mathutils import Vector


OUTPUT_BLEND = r"C:\Users\poops\OneDrive\Desktop\Towerdefense\blender_assets\farm_gauntlet_ready.blend"
OUTPUT_PNG = r"C:\Users\poops\OneDrive\Desktop\Towerdefense\assets\maps\farm_gauntlet.png"


def srgb(hex_color):
    value = hex_color.lstrip("#")
    channels = [int(value[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    linear = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in channels]
    return (*linear, 1.0)


def material(name, dark, base, light):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    nodes.clear()
    diffuse = nodes.new("ShaderNodeBsdfDiffuse")
    diffuse.inputs["Color"].default_value = srgb(base)
    diffuse.inputs["Roughness"].default_value = 0.9
    shader_to_rgb = nodes.new("ShaderNodeShaderToRGB")
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "CONSTANT"
    ramp.color_ramp.elements[0].position = 0.30
    ramp.color_ramp.elements[0].color = srgb(dark)
    ramp.color_ramp.elements[1].position = 0.58
    ramp.color_ramp.elements[1].color = srgb(base)
    highlight = ramp.color_ramp.elements.new(0.78)
    highlight.color = srgb(light)
    output = nodes.new("ShaderNodeOutputMaterial")
    mat.node_tree.links.new(diffuse.outputs[0], shader_to_rgb.inputs[0])
    mat.node_tree.links.new(shader_to_rgb.outputs[0], ramp.inputs[0])
    mat.node_tree.links.new(ramp.outputs[0], output.inputs[0])
    return mat


MATS = {
    "grass": material("Grass", "#3F7627", "#79B82A", "#A6D73D"),
    "grass_dark": material("Dark Grass", "#284D24", "#3F7627", "#72A934"),
    "dirt": material("Dirt Road", "#A76730", "#E3A044", "#F2C468"),
    "soil": material("Plowed Soil", "#42291E", "#704326", "#9C6334"),
    "wheat": material("Wheat", "#95651F", "#EDB52E", "#F4D45A"),
    "wood": material("Wood", "#42291D", "#75451F", "#AD7131"),
    "red": material("Barn Red", "#682822", "#C64632", "#E36445"),
    "roof": material("Roof", "#272A2F", "#505862", "#77818A"),
    "metal": material("Metal", "#37434B", "#687782", "#A9B5B5"),
    "leaf": material("Leaves", "#294D25", "#517C26", "#90BA36"),
    "leaf_light": material("Light Leaves", "#3F6624", "#75A62F", "#A6D73D"),
    "water": material("Pond Water", "#174B62", "#269EAD", "#45C4C0"),
    "stone": material("Stone", "#484C43", "#747761", "#A7AA83"),
}


def assign(obj, mat):
    obj.data.materials.append(mat)
    return obj


def box(name, location, scale, mat, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0.0:
        mod = obj.modifiers.new("Soft Corners", "BEVEL")
        mod.width = bevel
        mod.segments = 1
    assign(obj, mat)
    return obj


def cylinder(name, location, radius, depth, mat, vertices=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location)
    obj = bpy.context.object
    obj.name = name
    assign(obj, mat)
    return obj


def triangular_roof(name, location, width, depth, height, mat):
    x = width / 2.0
    y = depth / 2.0
    z = height
    verts = [(-x, -y, 0), (x, -y, 0), (x, y, 0), (-x, y, 0), (0, -y, z), (0, y, z)]
    faces = [(0, 1, 4), (3, 5, 2), (0, 4, 5, 3), (1, 2, 5, 4), (0, 3, 2, 1)]
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    assign(obj, mat)
    return obj


def low_tree(name, x, y, scale=1.0, light=False):
    cylinder(name + " Trunk", (x, y, 0.55 * scale), 0.14 * scale, 1.1 * scale, MATS["wood"], 8)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.75 * scale, location=(x, y, 1.45 * scale))
    crown = bpy.context.object
    crown.name = name + " Crown"
    crown.scale = (1.0, 0.9, 0.85)
    assign(crown, MATS["leaf_light"] if light else MATS["leaf"])


def flat_blob(name, x, y, sx, sy, mat):
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=1.0, depth=0.035, location=(x, y, 0.025))
    obj = bpy.context.object
    obj.name = name
    obj.scale = (sx, sy, 1.0)
    assign(obj, mat)
    return obj


def fence(name, x1, y1, x2, y2):
    direction = Vector((x2 - x1, y2 - y1))
    length = direction.length
    angle = math.atan2(direction.y, direction.x)
    center = ((x1 + x2) / 2.0, (y1 + y2) / 2.0)
    for offset, height in ((0.0, 0.42), (0.0, 0.82)):
        rail = box(name + " Rail", (center[0], center[1], height), (length, 0.10, 0.10), MATS["wood"])
        rail.rotation_euler.z = angle
    posts = max(2, int(length / 1.25) + 1)
    for i in range(posts):
        t = i / (posts - 1)
        px = x1 + (x2 - x1) * t
        py = y1 + (y2 - y1) * t
        box(name + " Post", (px, py, 0.52), (0.14, 0.14, 1.04), MATS["wood"])


def make_road():
    points = [(-16.0, 5.94)]
    points.append((10.94, 5.94))
    center = Vector((10.94, 3.595))
    for i in range(1, 13):
        angle = math.radians(90.0 - i * 15.0)
        points.append((center.x + 2.345 * math.cos(angle), center.y + 2.345 * math.sin(angle)))
    points.append((-10.84, 1.25))
    center = Vector((-10.84, -1.095))
    for i in range(1, 13):
        angle = math.radians(90.0 + i * 15.0)
        points.append((center.x + 2.345 * math.cos(angle), center.y + 2.345 * math.sin(angle)))
    points.append((10.94, -3.44))
    center = Vector((10.94, -5.55))
    for i in range(1, 13):
        angle = math.radians(90.0 - i * 15.0)
        points.append((center.x + 2.11 * math.cos(angle), center.y + 2.11 * math.sin(angle)))
    points.append((-16.0, -7.66))
    curve = bpy.data.curves.new("Enemy Road", "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 1
    curve.bevel_depth = 0.93
    curve.bevel_resolution = 0
    spline = curve.splines.new("POLY")
    spline.points.add(len(points) - 1)
    for point, coordinates in zip(spline.points, points):
        point.co = (coordinates[0], coordinates[1], 0.18, 1.0)
    road = bpy.data.objects.new("ENEMY_ROAD", curve)
    bpy.context.collection.objects.link(road)
    road.scale.z = 0.08
    assign(road, MATS["dirt"])


def crop_field(name, x, y, width, depth):
    box(name + " Soil", (x, y, 0.035), (width, depth, 0.07), MATS["soil"], 0.12)
    row_count = max(3, int(depth / 0.34))
    for row in range(row_count):
        ry = y - depth / 2.0 + 0.22 + row * ((depth - 0.44) / max(row_count - 1, 1))
        for col in range(max(4, int(width / 0.42))):
            rx = x - width / 2.0 + 0.24 + col * 0.42
            height = 0.32 + 0.08 * ((row + col) % 3)
            cylinder(name + " Crop", (rx, ry, height / 2.0 + 0.07), 0.055, height, MATS["wheat"], 6)


def clear_scene():
    for obj in list(bpy.context.scene.objects):
        bpy.data.objects.remove(obj, do_unlink=True)


clear_scene()
ground = box("GROUND_30x20", (0, 0, -0.12), (30.0, 20.0, 0.24), MATS["grass"])
make_road()

# North farmstead.
box("Farmhouse", (-11.3, 8.1, 0.8), (3.6, 2.0, 1.6), MATS["red"], 0.08)
triangular_roof("Farmhouse Roof", (-11.3, 8.1, 1.6), 4.1, 2.35, 1.15, MATS["roof"])
box("Farmhouse Door", (-11.3, 7.05, 0.6), (0.65, 0.10, 1.2), MATS["wood"])
box("Windmill Tower", (-6.6, 8.1, 1.25), (0.42, 0.42, 2.5), MATS["wood"])
cylinder("Windmill Hub", (-6.6, 7.84, 2.55), 0.22, 0.34, MATS["metal"], 10).rotation_euler.x = math.radians(90)
for angle in (0, 45, 90, 135):
    blade = box("Windmill Blade", (-6.6, 7.66, 2.55), (2.4, 0.12, 0.28), MATS["metal"])
    blade.rotation_euler.y = math.radians(angle)
for hx, hy, hz in ((-3.7, 8.2, 0.42), (-2.75, 8.2, 0.42), (-3.2, 8.2, 1.22)):
    box("Hay Bale", (hx, hy, hz), (0.82, 0.75, 0.75), MATS["wheat"], 0.08)

# Orchard and pond stay around the outer frame.
for index, (tx, ty) in enumerate(((6.2, 8.45), (8.0, 8.0), (9.8, 8.55), (11.5, 8.0), (13.2, 8.55))):
    low_tree("Orchard %02d" % index, tx, ty, 0.82 + 0.05 * (index % 2), index % 2 == 0)
flat_blob("Pond", 1.6, 8.25, 2.2, 0.9, MATS["water"])
for rx, ry in ((-0.5, 8.5), (3.7, 8.4), (2.9, 7.6)):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.34, location=(rx, ry, 0.2))
    assign(bpy.context.object, MATS["stone"])

# Fields and central landmark.
crop_field("North Crop Field", -8.5, 3.25, 7.3, 1.75)
crop_field("South Crop Field", 7.4, -1.9, 6.8, 1.55)
box("Barn", (0.0, -1.1, 1.0), (5.2, 2.35, 2.0), MATS["red"], 0.08)
triangular_roof("Barn Roof", (0.0, -1.1, 2.0), 5.8, 2.8, 1.4, MATS["red"])
box("Barn Door", (0.0, -2.3, 0.85), (1.15, 0.12, 1.7), MATS["wood"])
cylinder("Silo", (4.1, -1.0, 1.55), 0.95, 3.1, MATS["metal"], 14)
bpy.ops.mesh.primitive_uv_sphere_add(segments=14, ring_count=7, radius=0.96, location=(4.1, -1.0, 3.08))
silo_top = bpy.context.object
silo_top.scale.z = 0.45
assign(silo_top, MATS["metal"])

# Low fences and scattered rocks frame areas without filling priority pockets.
fence("North Fence A", -14.5, 6.75, -8.9, 6.75)
fence("North Fence B", -4.6, 6.75, -0.6, 6.75)
fence("South Fence", -14.5, -9.1, -7.0, -9.1)
for index, (rx, ry, size) in enumerate(((-3.6, 2.0, .3), (3.8, 2.05, .36), (-4.5, -5.2, .35), (6.7, -5.0, .32), (-9.0, -8.8, .28))):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=size, location=(rx, ry, size * .45))
    rock = bpy.context.object
    rock.name = "Rock %02d" % index
    rock.scale.z = 0.65
    assign(rock, MATS["stone"])

# Camera and lighting.
bpy.ops.object.camera_add(location=(0, 0, 30), rotation=(0, 0, 0))
camera = bpy.context.object
camera.name = "EXPORT_CAMERA_960x648"
camera.data.type = "ORTHO"
camera.data.ortho_scale = 30.0
bpy.context.scene.camera = camera
bpy.ops.object.light_add(type="SUN", location=(-8, -10, 18))
sun = bpy.context.object
sun.name = "Map Key Sun"
sun.rotation_euler = (math.radians(18), math.radians(-24), math.radians(-32))
sun.data.energy = 2.0
sun.data.angle = math.radians(7.0)
sun.data.color = (1.0, 0.91, 0.76)

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 960
scene.render.resolution_y = 648
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.filepath = OUTPUT_PNG
scene.render.film_transparent = False
scene.render.use_freestyle = True
scene.render.line_thickness = 1.25
scene.view_settings.look = "None"
scene.view_settings.view_transform = "Standard"
scene.view_settings.exposure = 0.0
scene.view_settings.gamma = 1.0
scene.world.color = srgb("#1C2730")[:3]
if not scene.world.use_nodes:
    scene.world.use_nodes = True
background = scene.world.node_tree.nodes.get("Background")
background.inputs["Color"].default_value = srgb("#293746")
background.inputs["Strength"].default_value = 0.42

bpy.ops.wm.save_as_mainfile(filepath=OUTPUT_BLEND)
bpy.ops.render.render(write_still=True)
print("Created", OUTPUT_BLEND)
print("Rendered", OUTPUT_PNG)
