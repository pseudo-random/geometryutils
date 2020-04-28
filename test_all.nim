import test, utils

block:
  let
    a = Vec2(x: 2, y: 1)
    b = Vec2(x: 1, y: 1)
    c = Vec2(x: 2, y: 3)
  
  test "Vec2":
    a + b == Vec2(x: 3, y: 2)
    a - b == Vec2(x: 1)
    a * c == Vec2(x: 4, y: 3)
    a / b == a
    angle(b).to_deg() == Deg(45)
    b.normalize().length().between(0.99, 1.01)
    dist(a, c) == 2

block:
  let
    a = Vec3(x: 1)
    b = Vec3(x: 1, y: 1, z: 1)
    c = Vec3(x: 2, y: 3, z: 4)

  test "Vec3":
    a + b == Vec3(x: 2, y: 1, z: 1)
    b - a == Vec3(y: 1, z: 1)
    b * c == c
    a * c == Vec3(x: 2)
    b.normalize().length().between(0.99, 1.01)
    a.normalize().length().between(0.99, 1.01)
    c.normalize().length().between(0.99, 1.01)
    c.xy == Vec2(x: 2, y: 3)
    c.yz == Vec2(x: 3, y: 4)
    c.xz == Vec2(x: 2, y: 4)
    a.rotate_z(Deg(90)).x.between(-0.001, 0.001)
    a.rotate_z(Deg(90)).y.between(0.999, 1.001)

block:
  let a = Box3(
    min: Vec3(x: -1, y: -1, z: -1),
    max: Vec3(x: 1, y: 1, z: 1)
  )
  
  test "Box3":
    a.center == Vec3()
    a.size == Vec3(x: 2, y: 2, z: 2)
