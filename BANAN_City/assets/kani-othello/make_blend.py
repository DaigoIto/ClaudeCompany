# kani-othello: 元データ(Blender)の作成 (headless)
#   blender -b --python make_blend.py
# 五目並べの卓(kani_gomoku_table)を黒檀色にして使い、オセロ盤と白黒の円盤を作る。
# 出力: kani_othello.blend / ot_tex_table.png / ot_tex_board.png / preview.png (このスクリプトと同じフォルダ)
import bpy, bmesh, os, math
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
GOMOKU = os.path.abspath(os.path.join(HERE, "..", "kani-gomoku"))

bpy.ops.wm.open_mainfile(filepath=os.path.join(GOMOKU, "kani_gomoku.blend"))

# ---- 不要物を消す(卓だけ残す)
table = bpy.data.objects["kani_gomoku_table"]
for o in list(bpy.data.objects):
    if o is not table:
        bpy.data.objects.remove(o, do_unlink=True)
table.name = "kani_othello_table"
table.data.name = "kani_othello_table"

# ---- 卓を黒檀色に: 元の木目テクスチャを暗くする(木目は薄く残す)
src = bpy.data.images["kg_tex_table"]
w, h = src.size
px = np.array(src.pixels[:], dtype=np.float32).reshape(h, w, 4)
lum = px[:, :, :3].mean(axis=2, keepdims=True)
lum = (lum - lum.min()) / max(lum.max() - lum.min(), 1e-6)          # 0..1 に正規化した木目の濃淡
# 黒檀色(炭のような黒)。真っ黒にすると、ゲーム内の陰影で縁の面取りだけが沈んで「段差」に見える。
# 木目と縁の丸みが見えるよう、0.11〜0.20(DDS で 28〜51)程度の濃さにする
dark = np.zeros_like(px)
dark[:, :, 0] = 0.115 + lum[:, :, 0] * 0.085
dark[:, :, 1] = 0.115 + lum[:, :, 0] * 0.085
dark[:, :, 2] = 0.130 + lum[:, :, 0] * 0.095                          # わずかに青み(黒檀の艶)
dark[:, :, 3] = 1.0
img = bpy.data.images.new("ot_tex_table", w, h, alpha=False)
img.pixels.foreach_set(dark.ravel())
img.filepath_raw = os.path.join(HERE, "ot_tex_table.png"); img.file_format = 'PNG'; img.save()
mat = table.data.materials[0]
mat.name = "ot_table_black"
for n in mat.node_tree.nodes:
    if n.type == 'TEX_IMAGE':
        n.image = img
bsdf = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
bsdf.inputs['Roughness'].default_value = 0.35

# ---- オセロ盤のテクスチャ: 枠(茶) + 緑のフェルト + 8×8 の線 + 星
SIZE = 0.672          # 盤の一辺(m)。五目並べの碁盤と同じ
GRID = 0.600          # マス目全体の一辺(m)。1マス 0.075
T = 2048
tex = np.zeros((T, T, 4), dtype=np.float32)
frame = np.array([0.20, 0.11, 0.05, 1.0], dtype=np.float32)
felt = np.array([0.04, 0.34, 0.17, 1.0], dtype=np.float32)
line = np.array([0.01, 0.07, 0.035, 1.0], dtype=np.float32)
tex[:, :] = frame
m = (SIZE - GRID) / 2 / SIZE                      # 枠の割合
a, b = int(round(m * T)), int(round((1 - m) * T))
tex[a:b, a:b] = felt
cell = (b - a) / 8
lw = 3                                            # 線の太さ(px)
for i in range(9):
    p = int(round(a + i * cell))
    tex[a:b, max(p - lw // 2, 0):p + lw // 2 + 1] = line
    tex[max(p - lw // 2, 0):p + lw // 2 + 1, a:b] = line
for gx in (2, 6):
    for gy in (2, 6):
        cx, cy = a + gx * cell, a + gy * cell
        yy, xx = np.ogrid[:T, :T]
        tex[(xx - cx) ** 2 + (yy - cy) ** 2 <= 9 ** 2] = line
# 枠の内側に細い縁取り
for p in (a - 3, b + 2):
    tex[p:p + 3, a - 3:b + 5] = line
    tex[a - 3:b + 5, p:p + 3] = line
# 画像は下から上の順で保持される
bimg = bpy.data.images.new("ot_tex_board", T, T, alpha=False)
bimg.pixels.foreach_set(np.flipud(tex).ravel())
bimg.filepath_raw = os.path.join(HERE, "ot_tex_board.png"); bimg.file_format = 'PNG'; bimg.save()

def tex_material(name, image, rough=0.6):
    mt = bpy.data.materials.new(name); mt.use_nodes = True
    nt = mt.node_tree
    bs = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    bs.inputs['Roughness'].default_value = rough
    tn = nt.nodes.new('ShaderNodeTexImage'); tn.image = image
    nt.links.new(tn.outputs['Color'], bs.inputs['Base Color'])
    return mt

def solid_material(name, rgb, rough=0.35):
    mt = bpy.data.materials.new(name); mt.use_nodes = True
    bs = next(n for n in mt.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bs.inputs['Base Color'].default_value = (*rgb, 1.0)
    bs.inputs['Roughness'].default_value = rough
    return mt

# ---- オセロ盤: 厚み 0.02 の板。原点は底の中心(五目並べの碁盤と同じ)。上面だけ全面テクスチャ
H = 0.02
bm = bmesh.new()
bmesh.ops.create_cube(bm, size=1.0)
for v in bm.verts:
    v.co.x *= SIZE; v.co.y *= SIZE; v.co.z = (v.co.z + 0.5) * H
uv = bm.loops.layers.uv.new("UVMap")
for f in bm.faces:
    top = f.normal.z > 0.9
    for l in f.loops:
        if top:
            l[uv].uv = (l.vert.co.x / SIZE + 0.5, l.vert.co.y / SIZE + 0.5)
        else:
            l[uv].uv = (0.01, 0.01)               # 側面と底は枠の色
me = bpy.data.meshes.new("kani_othello_board"); bm.to_mesh(me); bm.free()
board = bpy.data.objects.new("kani_othello_board", me)
bpy.context.scene.collection.objects.link(board)
me.materials.append(tex_material("ot_board", bimg, 0.7))
board.location = (0, 0, 0.76 + 0.0)               # 卓の天板の高さ(確認用。ゲームでは天板に置き直す)

# ---- 円盤(直径 0.058 / 厚み 0.012)。原点は底の中心
def make_disc(name, rgb, rough):
    r, hh, bevel = 0.029, 0.012, 0.0018
    bmd = bmesh.new()
    bmesh.ops.create_cone(bmd, cap_ends=True, cap_tris=False, segments=48, radius1=r, radius2=r, depth=hh)
    for v in bmd.verts:
        v.co.z += hh / 2
    bmesh.ops.bevel(bmd, geom=list(bmd.edges), offset=bevel, segments=2, affect='EDGES')
    uvl = bmd.loops.layers.uv.new("UVMap")
    for f in bmd.faces:
        for l in f.loops:
            l[uvl].uv = (0.5 + l.vert.co.x / (2 * r), 0.5 + l.vert.co.y / (2 * r))
    md = bpy.data.meshes.new(name); bmd.to_mesh(md); bmd.free()
    for p in md.polygons:
        p.use_smooth = True
    ob = bpy.data.objects.new(name, md)
    bpy.context.scene.collection.objects.link(ob)
    md.materials.append(solid_material("ot_" + name.replace("kani_", ""), rgb, rough))
    return ob

white = make_disc("kani_disc_white", (0.86, 0.85, 0.80), 0.30)
black = make_disc("kani_disc_black", (0.012, 0.012, 0.014), 0.25)
white.location = (0.45, -0.7, 0.0)
black.location = (0.55, -0.7, 0.0)

# 確認用: 盤の上に初期配置の円盤を置いたコピー(書き出しには使わない。名前を stone_ にして build 側で消える)
step = GRID / 8
for gx, gy, col in ((3, 3, white), (4, 4, white), (4, 3, black), (3, 4, black)):
    c = col.copy(); c.data = col.data; c.name = "stone_%d_%d" % (gx, gy)
    bpy.context.scene.collection.objects.link(c)
    c.location = (-GRID / 2 + (gx + 0.5) * step, GRID / 2 - (gy + 0.5) * step, 0.76 + H)

# ---- プレビュー画像
sc = bpy.context.scene
sc.render.engine = 'BLENDER_EEVEE' if 'BLENDER_EEVEE' in [i.identifier for i in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items] else sc.render.engine
sc.render.resolution_x, sc.render.resolution_y = 800, 400
cam = bpy.data.cameras.new("cam"); co = bpy.data.objects.new("persp", cam)
sc.collection.objects.link(co); sc.camera = co
co.location = (0.55, -0.85, 1.45)
direction = Vector((0, 0, 0.78)) - co.location
co.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()
lamp = bpy.data.lights.new("sun", 'SUN'); lamp.energy = 3.0
lo = bpy.data.objects.new("sun", lamp); sc.collection.objects.link(lo)
lo.rotation_euler = (math.radians(50), 0, math.radians(30))
w = bpy.data.worlds.new("w"); w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.18, 0.18, 0.2, 1)
sc.world = w
sc.render.filepath = os.path.join(HERE, "preview.png")
bpy.ops.render.render(write_still=True)

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "kani_othello.blend"))
print("DONE", [o.name for o in bpy.data.objects])
