import bpy

scene = bpy.context.scene
print("VIEW", scene.view_settings.view_transform, scene.view_settings.look,
      scene.view_settings.exposure, scene.view_settings.gamma)
print("FREESTYLE", scene.render.use_freestyle, scene.render.line_thickness)
for layer in scene.view_layers:
    settings = layer.freestyle_settings
    for line_set in settings.linesets:
        style = line_set.linestyle
        print("LINESET", line_set.name,
              "silhouette", line_set.select_silhouette,
              "border", line_set.select_border,
              "crease", line_set.select_crease,
              "material", line_set.select_material_boundary)
        print("LINESTYLE", style.name, tuple(style.color), style.alpha, style.thickness,
              style.caps, style.thickness_position)

for material in bpy.data.materials:
    if not material.use_nodes or not material.node_tree:
        continue
    print("MATERIAL", material.name)
    for node in material.node_tree.nodes:
        print(" NODE", node.type, node.name, "loc", tuple(node.location))
        if node.type == "VALTORGB":
            print("  RAMP", node.color_ramp.interpolation,
                  [(e.position, tuple(e.color)) for e in node.color_ramp.elements])
        elif node.type == "VECT_MATH":
            print("  VECTOR", node.operation,
                  [(socket.name, tuple(socket.default_value) if hasattr(socket.default_value, "__len__") else socket.default_value)
                   for socket in node.inputs])
        elif node.type == "MAP_RANGE":
            print("  MAP", node.clamp,
                  [(socket.name, tuple(socket.default_value) if hasattr(socket.default_value, "__len__") else socket.default_value)
                   for socket in node.inputs])
    for link in material.node_tree.links:
        print(" LINK", link.from_node.name, link.from_socket.name, "->",
              link.to_node.name, link.to_socket.name)
