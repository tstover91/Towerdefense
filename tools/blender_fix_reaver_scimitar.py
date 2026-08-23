import bmesh
import bpy


MODEL_PATH = (
    r"C:\Users\poops\OneDrive\Documents\alien tower defense\towers"
    r"\reaver base.blend"
)


old_blade = bpy.data.objects.get("Reaver_Energy_Scimitar_Blade")
weapon_assembly = None
if old_blade is not None:
    blade_material = old_blade.data.materials[0] if old_blade.data.materials else None
    bpy.data.objects.remove(old_blade, do_unlink=True)
else:
    # The artist used Separate/Join after creation. Find the combined weapon by
    # its energy material, delete only that loose blade geometry, and preserve
    # the hilt, grip, and guard geometry in the assembly.
    for candidate in bpy.context.scene.objects:
        if candidate.type != "MESH":
            continue
        material_names = [material.name for material in candidate.data.materials]
        if "Reaver Scimitar Energy" in material_names:
            weapon_assembly = candidate
            break
    if weapon_assembly is None:
        raise RuntimeError("No object using the Reaver energy material was found.")
    blade_material = bpy.data.materials.get("Reaver Scimitar Energy")
    energy_index = next(
        index
        for index, material in enumerate(weapon_assembly.data.materials)
        if material is not None and material.name == "Reaver Scimitar Energy"
    )
    bpy.context.view_layer.objects.active = weapon_assembly
    weapon_assembly.select_set(True)
    for polygon in weapon_assembly.data.polygons:
        polygon.select = polygon.material_index == energy_index
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.delete(type="VERT")
    bpy.ops.object.mode_set(mode="OBJECT")
    weapon_assembly.name = "Reaver_Scimitar_Hilt_Assembly"

# One simple non-self-intersecting scimitar outline, extruded directly into a
# closed prism. There are no segmented front faces for Freestyle to ink.
outline_xz = [
    (-0.445, 0.410),
    (-0.500, 0.335),
    (-0.575, 0.260),
    (-0.660, 0.200),
    (-0.750, 0.165),
    (-0.835, 0.170),
    (-0.915, 0.225),
    (-0.985, 0.320),
    (-1.005, 0.395),
    (-0.945, 0.350),
    (-0.890, 0.295),
    (-0.820, 0.250),
    (-0.750, 0.240),
    (-0.685, 0.260),
    (-0.615, 0.300),
    (-0.545, 0.360),
    (-0.485, 0.425),
]
front_y = -0.142
back_y = -0.118
front = [(x, front_y, z) for x, z in outline_xz]
back = [(x, back_y, z) for x, z in outline_xz]
vertices = front + back
count = len(outline_xz)
faces = [
    tuple(range(count)),
    tuple(range(count, count * 2))[::-1],
]
for index in range(count):
    next_index = (index + 1) % count
    faces.append((index, next_index, count + next_index, count + index))

mesh = bpy.data.meshes.new("Reaver Energy Scimitar Blade Mesh")
mesh.from_pydata(vertices, [], faces)
mesh.update(calc_edges=True)
mesh.validate(verbose=True, clean_customdata=True)

blade = bpy.data.objects.new("Reaver_Energy_Scimitar_Blade", mesh)
bpy.context.scene.collection.objects.link(blade)
if blade_material is not None:
    blade.data.materials.append(blade_material)

armature = bpy.data.objects.get("Armature")
if armature is None:
    raise RuntimeError("The Reaver armature was not found.")
world_matrix = blade.matrix_world.copy()
blade.parent = armature
blade.parent_type = "BONE"
blade.parent_bone = "Hand.R"
blade.matrix_world = world_matrix

if weapon_assembly is not None:
    assembly_world = weapon_assembly.matrix_world.copy()
    weapon_assembly.parent = armature
    weapon_assembly.parent_type = "BONE"
    weapon_assembly.parent_bone = "Hand.R"
    weapon_assembly.matrix_world = assembly_world

bm = bmesh.new()
bm.from_mesh(mesh)
non_manifold_edges = sum(1 for edge in bm.edges if not edge.is_manifold)
bm.free()
if non_manifold_edges != 0:
    raise RuntimeError(
        f"Corrected blade still has {non_manifold_edges} non-manifold edges."
    )

bpy.ops.wm.save_as_mainfile(filepath=MODEL_PATH)
print(f"SCIMITAR_NON_MANIFOLD_EDGES={non_manifold_edges}")
print(f"SAVED_CORRECTED_REAVER={MODEL_PATH}")
