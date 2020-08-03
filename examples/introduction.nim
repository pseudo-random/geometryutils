import geometryutils/[utils]

# The most important data structures provided by the
# geometryutils module are the vector types.

echo Vec2(x: 1, y: 2)
echo Vec3(x: 1, y: 2, z: 3)
echo Vec4(x: 1, y: 2, z: 3, w: 4)

echo Vec2(x: 1, y: 2) + Vec2(x: 3, y: 4) # Vec2(x: 4, y: 6)
echo Vec2(x: 1, y: 2) - Vec2(x: 3, y: 4) # Vec2(x: -2, y: -2)
echo Vec2(x: 1, y: 2) * Vec2(x: 3, y: 4) # Vec2(x: 3, y: 8)
echo Vec2(x: 1, y: 2) / Vec2(x: 3, y: 4) # Vec2(x: 1 / 3, y: 2 / 4)

echo length(Vec2(x: 3, y: 4)) # 5
echo Vec2(x: 3, y: 4).normalize().length() # 1
echo dist(Vec2(x: 1, y: 2), Vec2(x: 3, y: 2)) # 2
echo dot(Vec2(x: 1), Vec2(y: 1)) # 0
echo cross(Vec3(x: 1), Vec3(y: 1)) # Vec3(z: 1)

echo Vec3(x: 1).rotate_z(Deg(90)) # ~ Vec3(y: 1)

# The vector types provided are generic. You can
# instantiate Vector2[T], Vector3[T] and Vector4[T]
# to create new vector types.

type FloatVec3 = Vector3[float32]
echo FloatVec3(x: 1, y: 2, z: 3) + FloatVec3(z: 4) # FloatVec3(x: 1, y: 2, z: 7)

# Quaternions can be used to represent rotations in
# three dimensional space

let
  my_rot = new_quat(Vec3(z: 1), Deg(90))
  my_rot2 = new_quat(Vec3(z: 1), Deg(90))

echo my_rot * my_rot2 # ~ new_quat(Vec3(z: 1), Deg(180))
echo my_rot.length() # 1

let my_rot_mat = new_rotate_mat4(my_rot)
echo my_rot_mat * Vec4(x: 1) # ~ Vec4(y: 1)

# The Color type is used to represent colors

echo rgb(0xff0000) # Color(r: 1, a: 1)
echo rgb(1, 0, 0) # Color(r: 1, a: 1)

echo rgba(0, 0, 0, 0) # Color()
echo grey(0.5) # Color(r: 0.5, g: 0.5, b: 0.5, a: 1.0)

# The vectorrender2 submodule can be used to easily
# draw 2d vector graphics

import geometryutils/vectorrender2
var ren = new_vector_render2(Index2(x: 640, y: 480))
ren.background(grey(1))

ren.stroke = rgba(0)
ren.fill = rgb(0.1, 0.6, 0.8)
ren.rect(Vec2(x: 50, y: 50), Vec2(x: 200, y: 100))

ren.stroke = grey(0)
ren.fill = rgba(0)
ren.circle(ren.size.to_vec2() / 2, 100)

ren.stroke = grey(0)
ren.stroke_width = 4
ren.line(Vec2(x: 10, y: 10), Vec2(x: 30, y: 100))

ren.stroke = rgba(0)
ren.fill = grey(0)
ren.font_size = 50
ren.text(Vec2(x: 50, y: 50), "Hello, world")

import xmltree
write_file("my_image.svg", $ren.to_svg())
