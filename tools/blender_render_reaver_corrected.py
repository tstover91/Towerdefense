import bpy


REFERENCE = (
    r"C:\Users\poops\OneDrive\Documents\alien tower defense\towers"
    r"\Master base alien - Cel Damage.blend"
)
OUTPUT = (
    r"C:\Users\poops\OneDrive\Documents\alien tower defense\towers"
    r"\reaver base - Cel Damage corrected.png"
)


def set_ramp(material, colors):
    ramp = next(
        node.color_ramp
        for node in material.node_tree.nodes
        if node.type == "VALTORGB"
    )
    ramp.interpolation = "CONSTANT"
    for element, color in zip(ramp.elements, colors):
        element.color = color


def variant(source, name, colors):
    material = source.copy()
    material.name = name
    set_ramp(material, colors)
    return material


scene = bpy.context.scene
with bpy.data.libraries.load(REFERENCE, link=False) as (source, target):
    target.materials = ["Skin", "Eyes", "Material.001"]
    target.objects = ["Cel Damage Camera", "Cel Damage Key Light"]

skin, eyes, black = target.materials
for obj in target.objects:
    if obj is not None and not obj.users_collection:
        scene.collection.objects.link(obj)
scene.camera = next(obj for obj in target.objects if obj.type == "CAMERA")

cloth = variant(skin, "Reaver Cel Burgundy", [
    (0.028, 0.002, 0.012, 1.0),
    (0.220, 0.025, 0.095, 1.0),
    (0.580, 0.120, 0.260, 1.0),
])
armor = variant(skin, "Reaver Cel Armor", [
    (0.003, 0.006, 0.016, 1.0),
    (0.035, 0.065, 0.135, 1.0),
    (0.150, 0.245, 0.420, 1.0),
])
hilt = variant(skin, "Reaver Cel Hilt", [
    (0.004, 0.005, 0.008, 1.0),
    (0.060, 0.070, 0.095, 1.0),
    (0.300, 0.335, 0.390, 1.0),
])
wrap = variant(skin, "Reaver Cel Wrap", [
    (0.030, 0.004, 0.040, 1.0),
    (0.260, 0.045, 0.330, 1.0),
    (0.610, 0.190, 0.700, 1.0),
])
energy = variant(skin, "Reaver Cel Energy", [
    (0.010, 0.480, 0.650, 1.0),
    (0.010, 0.720, 0.900, 1.0),
    (0.500, 1.000, 1.000, 1.0),
])

mapping = {
    "Skin": skin,
    "Eyes": eyes,
    "Material.001": black,
    "Reaver Cloth": cloth,
    "Reaver Armor": armor,
    "Reaver Scimitar Hilt": hilt,
    "Reaver Scimitar Wrap": wrap,
    "Reaver Scimitar Energy": energy,
}
for obj in scene.objects:
    if obj.type != "MESH":
        continue
    for slot in obj.material_slots:
        if slot.material is not None and slot.material.name in mapping:
            slot.material = mapping[slot.material.name]

scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 512
scene.render.resolution_y = 512
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.film_transparent = True
scene.render.use_freestyle = True
scene.render.line_thickness_mode = "ABSOLUTE"
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "None"

world = scene.world
world.use_nodes = True
background = next(node for node in world.node_tree.nodes if node.type == "BACKGROUND")
background.inputs["Color"].default_value = (0.055, 0.065, 0.085, 1.0)
background.inputs["Strength"].default_value = 0.42

line_sets = scene.view_layers[0].freestyle_settings.linesets
while len(line_sets):
    line_sets.remove(line_sets[0])
outer = line_sets.new("Outer Ink")
outer.select_silhouette = True
outer.select_border = True
outer.select_contour = True
outer.select_crease = False
outer.select_material_boundary = False
outer.linestyle.color = (0.001, 0.001, 0.001)
outer.linestyle.thickness = 9.0
interior = line_sets.new("Interior Ink")
interior.select_silhouette = False
interior.select_border = False
interior.select_contour = False
interior.select_crease = True
interior.select_material_boundary = True
interior.linestyle.color = (0.001, 0.001, 0.001)
interior.linestyle.thickness = 4.5

scene.render.filepath = OUTPUT
bpy.ops.render.render(write_still=True)
print(f"SAVED_CORRECTED_CEL_RENDER={OUTPUT}")
