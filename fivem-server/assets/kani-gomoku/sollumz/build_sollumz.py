# kani-gomoku: Blender原本 -> Sollumz -> ydr/ytyp 書き出し (headless)
# blender -b --python build.py -- <OUT_DIR> <FORMAT: CWXML|NATIVE>
import bpy, addon_utils, os, sys, struct, bmesh
import numpy as np
from mathutils import Vector

addon_utils.enable('Sollumz')
args = sys.argv[sys.argv.index('--') + 1:]
OUT, FMT = args[0], (args[1] if len(args) > 1 else 'CWXML')
ASSET = r"C:\Users\tohay\Documents\ClaudeCompany\fivem-server\assets\kani-gomoku"
TEX = os.path.join(OUT, 'tex'); os.makedirs(TEX, exist_ok=True)
NAMES = ['kani_gomoku_table', 'kani_goban', 'kani_stone_black', 'kani_stone_white']

bpy.ops.wm.open_mainfile(filepath=os.path.join(ASSET, "kani_gomoku.blend"))
sc = bpy.context.scene

def sel(objs):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]

# ---- 不要物削除・原点
for o in list(bpy.data.objects):
    if o.name not in NAMES: bpy.data.objects.remove(o, do_unlink=True)
for n in NAMES: bpy.data.objects[n].location = (0, 0, 0)
if 'lambert1' in bpy.data.materials: bpy.data.materials.remove(bpy.data.materials['lambert1'])

# ---- UV / 頂点カラーを GTA 用の名前に
for n in NAMES:
    me = bpy.data.objects[n].data
    if not me.uv_layers: me.uv_layers.new()
    me.uv_layers[0].name = 'UVMap 0'
    ca = me.color_attributes.new('Color 1', 'BYTE_COLOR', 'CORNER')
    ca.data.foreach_set('color', [1.0] * 4 * len(ca.data))

# ---- DDS (非圧縮 A8R8G8B8 + ミップマップ)
def write_dds(path, rgba):  # rgba: HxWx4 uint8, 上から下
    h, w = rgba.shape[:2]
    mips = [rgba]
    while min(mips[-1].shape[:2]) > 1:
        m = mips[-1].astype(np.float32)
        m = (m[0::2, 0::2] + m[1::2, 0::2] + m[0::2, 1::2] + m[1::2, 1::2]) / 4
        mips.append(m.round().astype(np.uint8))
    hdr = struct.pack('<4sI', b'DDS ', 124)
    flags = 0x1 | 0x2 | 0x4 | 0x8 | 0x1000 | 0x20000
    hdr += struct.pack('<6I', flags, h, w, w * 4, 0, len(mips)) + b'\0' * 44
    hdr += struct.pack('<2I4s5I', 32, 0x41, b'\0\0\0\0', 32, 0x00ff0000, 0x0000ff00, 0x000000ff, 0xff000000)
    hdr += struct.pack('<5I', 0x1000 | 0x400000 | 0x8, 0, 0, 0, 0)
    with open(path, 'wb') as f:
        f.write(hdr)
        for m in mips: f.write(m[:, :, [2, 1, 0, 3]].tobytes())

def image_rgba(img, size):
    if img.size[0] != size: img.scale(size, size)
    px = np.array(img.pixels[:], dtype=np.float32).reshape(img.size[1], img.size[0], 4)
    return (np.flipud(px) * 255 + 0.5).clip(0, 255).astype(np.uint8)

dds_for = {}
for m in list(bpy.data.materials):
    nt = m.node_tree
    if not nt: continue
    bsdf = next((x for x in nt.nodes if x.type == 'BSDF_PRINCIPLED'), None)
    tn = next((x for x in nt.nodes if x.type == 'TEX_IMAGE'), None)
    tname = 'kg_tex_' + m.name.replace('kg_', '')
    if tn and tn.image:
        rgba = image_rgba(tn.image.copy(), 512); tname = tn.image.name
    else:
        c = bsdf.inputs['Base Color'].default_value
        col = [int(round((max(c[i], 0) ** (1 / 2.2)) * 255)) for i in range(3)] + [255]
        rgba = np.tile(np.array(col, np.uint8), (16, 16, 1))
        tn = nt.nodes.new('ShaderNodeTexImage')
        nt.links.new(tn.outputs['Color'], bsdf.inputs['Base Color'])
    p = os.path.join(TEX, tname + '.dds'); write_dds(p, rgba)
    img = bpy.data.images.load(p); img.name = tname
    tn.image = img

# ---- Sollumz マテリアル・Drawable 化
for n in NAMES:
    o = bpy.data.objects[n]; sel([o])
    for i in range(len(o.material_slots)):
        o.active_material_index = i
        bpy.ops.sollumz.auto_convert_current_material()
    bpy.ops.sollumz.converttodrawable()
for m in bpy.data.materials:
    for x in (m.node_tree.nodes if m.node_tree else []):
        if x.type == 'TEX_IMAGE' and hasattr(x, 'texture_properties'):
            x.texture_properties.embedded = True

# ---- 卓の当たり判定: Composite + Box
table = bpy.data.objects['kani_gomoku_table']
def new_bound(kind, parent_sel):
    before = set(bpy.data.objects)
    sel([parent_sel]) if parent_sel else bpy.ops.object.select_all(action='DESELECT')
    sc.create_bound_type = kind
    bpy.ops.sollumz.createbound()
    new = [o for o in bpy.data.objects if o not in before]
    print("NEWBOUND", kind, [(o.name, o.sollum_type, o.parent.name if o.parent else None) for o in new])
    return next(o for o in new if o.sollum_type == kind)
comp = new_bound('sollumz_bound_composite', None)
comp.name = 'kani_table_col'; comp.parent = table
box = new_bound('sollumz_bound_box', comp)
box.name = 'kani_table_col_box'; box.parent = comp
for v in box.data.vertices:
    v.co.x *= 0.86 / max(box.dimensions.x, 1e-6) * box.scale.x if False else 1
d = box.dimensions.copy()
for v in box.data.vertices:
    v.co.x *= 0.86 / d.x; v.co.y *= 0.86 / d.y; v.co.z *= 0.76 / d.z
box.location = (0, 0, 0.38)
sel([box])
from Sollumz.ybn.collision_materials import collisionmats
idx = next((i for i, cm in enumerate(collisionmats) if cm.name.upper() == 'WOOD_SOLID_MEDIUM'), 0)
bpy.context.window_manager.sz_collision_material_index = idx
bpy.ops.sollumz.clearandcreatecollisionmaterial()
print("COLMAT", idx, [m.name for m in box.data.materials])
print("COLTREE", [(c.name, c.sollum_type, c.parent.name, tuple(round(v, 3) for v in c.dimensions)) for c in table.children_recursive])

# ---- ytyp (1つだけ)
bpy.ops.sollumz.createytyp()
y = sc.ytyps[sc.ytyp_index]; y.name = 'kani_gomoku'
sel([bpy.data.objects[n] for n in NAMES])
bpy.ops.sollumz.createarchetypefromselected()
for a in y.archetypes:
    ob = bpy.data.objects[a.name]
    pts = [m.matrix_world @ Vector(c) for m in ob.children_recursive
           if m.type == 'MESH' and m.sollum_type == 'sollumz_drawable_model' for c in m.bound_box]
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    a.bb_min, a.bb_max = mn, mx
    a.bs_center = (mn + mx) / 2; a.bs_radius = (mx - mn).length / 2
    a.lod_dist = 80.0
    print("ARCHE", a.name, a.texture_dictionary, tuple(round(v, 3) for v in mn), tuple(round(v, 3) for v in mx))
print("YTYPS", [(t.name, len(t.archetypes)) for t in sc.ytyps])

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "kani_gomoku_sollumz.blend"))

# ---- 書き出し
dst = os.path.join(OUT, FMT.lower()); os.makedirs(dst, exist_ok=True)
sel([bpy.data.objects[n] for n in NAMES])
r = bpy.ops.sollumz.export_assets(directory=dst, direct_export=True, use_custom_settings=True,
                                  target_formats={FMT}, target_versions={'GEN8'}, limit_to_selected=True,
                                  export_ytyps=True, export_ytyps_include='ALL')
print("EXPORT", r)
for root, ds, fs in os.walk(dst):
    for f in fs: print("FILE", os.path.relpath(os.path.join(root, f), dst), os.path.getsize(os.path.join(root, f)))
