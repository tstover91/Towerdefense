import math
from pathlib import Path

import bpy
from mathutils import Vector


OUTPUT = Path(
    r"C:\Users\poops\OneDrive\Desktop\Towerdefense\blender_assets\renders\farm_map_invader_reference_cel.png"
)


# The Invader reference uses (-0.38, -0.53, 0.76). A lower elevation keeps
# horizontal terrain in its middle band for a straight top-down map.
LIGHT_DIRECTION = (-0.72, -0.66, 0.20)


def aim_at(obj, target):
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def shade_colors(base):
    shadow = tuple(channel * 0.22 for channel in base[:3]) + (1.0,)
    middle = tuple(base[:3]) + (1.0,)
    highlight = tuple(channel * 0.62 + 0.38 for channel in base[:3]) + (1.0,)
    return shadow, middle, highlight


def add_normal_band_driver(nodes, links):
    geometry = nodes.new("ShaderNodeNewGeometry")
    geometry.name = "Smooth Surface Normal"
    dot = nodes.new("ShaderNodeVectorMath")
    dot.name = "Smooth Normal Dot Light"
    dot.operation = "DOT_PRODUCT"
    dot.inputs[1].default_value = LIGHT_DIRECTION
    remap = nodes.new("ShaderNodeMapRange")
    remap.name = "Remap Dot Product"
    remap.clamp = True
    remap.inputs["From Min"].default_value = -1.0
    remap.inputs["From Max"].default_value = 1.0
    links.new(geometry.outputs["Normal"], dot.inputs[0])
    links.new(dot.outputs["Value"], remap.inputs["Value"])
    return remap.outputs["Result"]


def build_solid_cel_material(material, base):
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    nodes.clear()
    band_factor = add_normal_band_driver(nodes, links)
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.name = "Three Clean Cel Bands"
    ramp.color_ramp.interpolation = "CONSTANT"
    colors = shade_colors(base)
    ramp.color_ramp.elements[0].position = 0.28
    ramp.color_ramp.elements[0].color = colors[0]
    ramp.color_ramp.elements[1].position = 0.56
    ramp.color_ramp.elements[1].color = colors[1]
    third = ramp.color_ramp.elements.new(0.78)
    third.color = colors[2]
    emission = nodes.new("ShaderNodeEmission")
    emission.name = "Stable Unlit Cel Color"
    output = nodes.new("ShaderNodeOutputMaterial")
    output.name = "Cel Material Output"
    links.new(band_factor, ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], emission.inputs["Color"])
    links.new(emission.outputs["Emission"], output.inputs["Surface"])


def build_textured_cel_material(material, base_socket):
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    old_outputs = [node for node in nodes if node.type == "OUTPUT_MATERIAL"]
    band_factor = add_normal_band_driver(nodes, links)

    mid_test = nodes.new("ShaderNodeMath")
    mid_test.operation = "GREATER_THAN"
    mid_test.inputs[1].default_value = 0.56
    high_test = nodes.new("ShaderNodeMath")
    high_test.operation = "GREATER_THAN"
    high_test.inputs[1].default_value = 0.78
    links.new(band_factor, mid_test.inputs[0])
    links.new(band_factor, high_test.inputs[0])

    shadow = nodes.new("ShaderNodeMixRGB")
    shadow.blend_type = "MULTIPLY"
    shadow.inputs[0].default_value = 1.0
    shadow.inputs[2].default_value = (0.22, 0.22, 0.22, 1.0)
    highlight = nodes.new("ShaderNodeMixRGB")
    highlight.blend_type = "MIX"
    highlight.inputs[0].default_value = 0.38
    highlight.inputs[2].default_value = (1.0, 1.0, 1.0, 1.0)
    links.new(base_socket, shadow.inputs[1])
    links.new(base_socket, highlight.inputs[1])

    choose_mid = nodes.new("ShaderNodeMixRGB")
    links.new(mid_test.outputs[0], choose_mid.inputs[0])
    links.new(shadow.outputs[0], choose_mid.inputs[1])
    links.new(base_socket, choose_mid.inputs[2])
    choose_high = nodes.new("ShaderNodeMixRGB")
    links.new(high_test.outputs[0], choose_high.inputs[0])
    links.new(choose_mid.outputs[0], choose_high.inputs[1])
    links.new(highlight.outputs[0], choose_high.inputs[2])

    emission = nodes.new("ShaderNodeEmission")
    emission.name = "Stable Unlit Cel Color"
    output = nodes.new("ShaderNodeOutputMaterial")
    output.name = "Cel Material Output"
    links.new(choose_high.outputs[0], emission.inputs["Color"])
    links.new(emission.outputs["Emission"], output.inputs["Surface"])
    for old_output in old_outputs:
        nodes.remove(old_output)


def tune_materials():
    hidden_guide_materials = {"Editor Grid Lines", "Map Boundary", "path", "Preview Grass"}
    for material in bpy.data.materials:
        if material.name in hidden_guide_materials:
            continue
        material.use_nodes = True
        nodes = material.node_tree.nodes
        output = next((node for node in nodes if node.type == "OUTPUT_MATERIAL" and node.is_active_output), None)
        surface_link = next((link for link in material.node_tree.links
                             if output and link.to_node == output and link.to_socket.name == "Surface"), None)
        principled = surface_link.from_node if surface_link and surface_link.from_node.type == "BSDF_PRINCIPLED" else None
        if principled is None:
            principled = next((node for node in nodes if node.type == "BSDF_PRINCIPLED"), None)
        if principled is None:
            continue
        base_input = principled.inputs["Base Color"]
        base_link = next((link for link in material.node_tree.links if link.to_socket == base_input), None)
        if base_link is not None:
            build_textured_cel_material(material, base_link.from_socket)
        else:
            base = tuple(base_input.default_value)
            if material.name == "Outline Charcoal":
                base = (0.008, 0.009, 0.014, 1.0)
            build_solid_cel_material(material, base)


def add_comic_bevels():
    exclusions = (
        "GROUND",
        "Road",
        "Soil",
        "Path",
        "Boundary",
        "Crop",
        "BézierCurve",
        "EDITABLE_GROUND",
    )
    for obj in bpy.data.objects:
        if obj.type != "MESH" or any(token in obj.name for token in exclusions):
            continue
        if any(modifier.type == "BEVEL" for modifier in obj.modifiers):
            continue
        smallest_dimension = min(obj.dimensions)
        if smallest_dimension <= 0.08:
            continue
        bevel = obj.modifiers.new(name="Cel Damage Edge Bevel", type="BEVEL")
        bevel.width = min(0.055, smallest_dimension * 0.18)
        bevel.segments = 1
        bevel.limit_method = "ANGLE"
        bevel.angle_limit = math.radians(25.0)


def configure_scene():
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1536
    scene.render.resolution_y = 1536
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.filepath = str(OUTPUT)
    scene.render.film_transparent = False
    scene.render.use_freestyle = True
    scene.render.line_thickness = 1.0

    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.view_settings.exposure = 0.0
    scene.view_settings.gamma = 1.0

    camera = bpy.data.objects.get("EXPORT_CAMERA_960x648") or scene.camera
    scene.camera = camera
    camera.location = (0.0, 0.0, 35.0)
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 32.0
    camera.rotation_euler = (0.0, 0.0, 0.0)

    world = scene.world
    world.use_nodes = True
    background = world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (0.055, 0.065, 0.085, 1.0)
    background.inputs["Strength"].default_value = 0.42

    for guide_name in (
        "TILE_GRID_GUIDE",
        "MAP_BOUNDARY_GUIDE",
        "EDIT_THIS_ENEMY_PATH",
    ):
        guide = bpy.data.objects.get(guide_name)
        if guide is not None:
            guide.hide_render = True

    for obj in bpy.data.objects:
        if obj.type == "LIGHT":
            obj.hide_render = obj.data.type != "SUN"
    sun = next((o for o in bpy.data.objects if o.type == "LIGHT" and o.data.type == "SUN"), None)
    if sun is not None:
        sun.data.energy = 3.0
        sun.data.angle = math.radians(7.5)
        sun.rotation_euler = (
            math.radians(32.0),
            math.radians(-24.0),
            math.radians(-32.0),
        )

    for view_layer in scene.view_layers:
        line_sets = view_layer.freestyle_settings.linesets
        while len(line_sets):
            line_sets.remove(line_sets[0])

        outer = line_sets.new("Outer Ink")
        outer.select_silhouette = True
        outer.select_border = True
        outer.select_crease = False
        outer.select_material_boundary = False
        outer.linestyle.color = (0.001, 0.001, 0.001)
        outer.linestyle.alpha = 1.0
        outer.linestyle.thickness = 9.0
        outer.linestyle.caps = "BUTT"

        interior = line_sets.new("Interior Ink")
        interior.select_silhouette = False
        interior.select_border = False
        interior.select_crease = True
        interior.select_material_boundary = True
        interior.linestyle.color = (0.001, 0.001, 0.001)
        interior.linestyle.alpha = 1.0
        interior.linestyle.thickness = 4.5
        interior.linestyle.caps = "BUTT"


OUTPUT.parent.mkdir(parents=True, exist_ok=True)
tune_materials()
configure_scene()
bpy.ops.render.render(write_still=True)
print(f"CEL_RENDER={OUTPUT}")
