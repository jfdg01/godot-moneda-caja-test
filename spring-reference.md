# Godot Spring Simulation — Implementation Guide

## Notes

A few things worth flagging explicitly:

`setup()` must be called after you change any parameter at runtime. If you add a debug UI that lets you tweak `omega_0` or `mass` live, call `setup()` in the setter — otherwise `_k` and `_b` go stale and the spring behaves wrong silently.

The `push()` function is the entire impulse system. No special case for mid-motion — you just call it. The velocity addition is all that needs to happen, and the simulation loop handles the rest from there regardless of what state the spring is in.

The `substeps` argument in `tick()` defaults to 4, which is safe for the whole `omega_0` range you'd use for body parts. If you ever push `omega_0` above ~20 and notice instability (spring exploding), raise substeps to 8. Below 20 you won't need it.

## Parameters you expose

| Parameter | Symbol | What it means |
|---|---|---|
| Natural frequency | `omega_0` | How fast it oscillates (rad/s). Typical range 2–15. |
| Damping ratio | `zeta` | Character: <1 bounces, =1 critical, >1 sluggish. |
| Mass | `mass` | Size of the body part. Same material = same omega_0/zeta, only mass changes. |
| Saturation | `sat_x`, `sat_v` | Displacement and velocity at which soft clamping kicks in. |

Everything else is derived. Never expose `k` or `b` directly.

```
k = omega_0² × mass
b = 2 × zeta × omega_0 × mass
```

---

## The SpringBody class

One file, drop it anywhere in your project.

```gdscript
class_name SpringBody
extends RefCounted

# --- Exposed parameters ---
var omega_0: float = 8.0
var zeta: float    = 0.35
var mass: float    = 1.0
var sat_x: float   = 40.0  # px — displacement soft limit
var sat_v: float   = 300.0 # px/s — velocity soft limit

# --- State ---
var position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var target:   Vector2 = Vector2.ZERO

# --- Derived (call after changing parameters) ---
var _k: float
var _b: float

func setup() -> void:
    _k = omega_0 * omega_0 * mass
    _b = 2.0 * zeta * omega_0 * mass

func teleport(pos: Vector2) -> void:
    position = pos
    target   = pos
    velocity = Vector2.ZERO

func push(impulse: Vector2) -> void:
    # Impulse = change in momentum. v += J/m
    velocity += impulse / mass

func tick(delta: float, substeps: int = 4) -> void:
    var dt: float = delta / substeps
    for _i in substeps:
        var disp: float  = (target - position).length()
        var disp_dir: Vector2 = (target - position) / max(disp, 0.001)

        # Soft-clamped restoring force (tanh saturation)
        var f_spring: Vector2 = disp_dir * _k * sat_x * tanh(disp / sat_x)

        # Soft-clamped damping force
        var speed: float = velocity.length()
        var vel_dir: Vector2 = velocity / max(speed, 0.001)
        var f_damp: Vector2 = vel_dir * _b * sat_v * tanh(speed / sat_v)

        var acceleration: Vector2 = (f_spring - f_damp) / mass
        velocity += acceleration * dt
        position += velocity * dt
```

Call `setup()` once after setting parameters, or whenever you change them.

---

## Using it in a node

```gdscript
extends Node2D

@onready var spine_sprite = $SpineSprite

var breast_l: SpringBody
var breast_r: SpringBody

func _ready() -> void:
    breast_l = SpringBody.new()
    breast_l.omega_0 = 7.0
    breast_l.zeta    = 0.35
    breast_l.mass    = 1.4   # larger = slower, same material
    breast_l.sat_x   = 35.0
    breast_l.sat_v   = 250.0
    breast_l.setup()

    breast_r = SpringBody.new()
    breast_r.omega_0 = 7.0
    breast_r.zeta    = 0.35
    breast_r.mass    = 1.4
    breast_r.sat_x   = 35.0
    breast_r.sat_v   = 250.0
    breast_r.setup()

    # Teleport to starting bone position so there's no startup snap
    breast_l.teleport(get_bone_world_pos("breast_l"))
    breast_r.teleport(get_bone_world_pos("breast_r"))

func _process(delta: float) -> void:
    # Move targets to wherever the chest bone is this frame
    breast_l.target = get_bone_world_pos("chest_l")
    breast_r.target = get_bone_world_pos("chest_r")

    breast_l.tick(delta)
    breast_r.tick(delta)

    # Apply offset back to the Spine bones
    set_bone_offset("breast_l", breast_l.position - breast_l.target)
    set_bone_offset("breast_r", breast_r.position - breast_r.target)

# --- Footfall or impact event ---
func on_footfall(foot: String) -> void:
    var impulse = Vector2(0, 180)  # downward kick, tune this
    breast_l.push(impulse)
    breast_r.push(impulse)
```

---

## Firing impulses

Just call `push()` with a `Vector2` impulse at any point — mid-oscillation, mid-air, doesn't matter. Velocity stacks naturally. No special handling needed.

```gdscript
# On landing
spring.push(Vector2(0, landing_force))

# On a hard lateral stop
spring.push(Vector2(-character_velocity.x * 0.3, 0))

# On an impact hit
spring.push(Vector2.from_angle(hit_direction) * hit_strength)
```

The impulse divides by mass automatically, so a heavier body part visibly reacts less to the same hit.

---

## Spine2D helper functions

```gdscript
func get_bone_world_pos(bone_name: String) -> Vector2:
    var bone = spine_sprite.get_skeleton().find_bone(bone_name)
    return Vector2(bone.get_world_x(), bone.get_world_y())

func set_bone_offset(bone_name: String, offset: Vector2) -> void:
    var bone = spine_sprite.get_skeleton().find_bone(bone_name)
    bone.set_x(bone.get_x() + offset.x)
    bone.set_y(bone.get_y() + offset.y)
```

---

## Tuning cheatsheet

| Feel | Adjust |
|---|---|
| Oscillates too fast | Lower `omega_0` |
| Too bouncy, won't settle | Lower `zeta` toward 0 |
| Settles without bouncing | Raise `zeta` toward or above 1 |
| Moves too little on impact | Raise impulse magnitude OR lower `mass` |
| Clips or moves too far | Lower `sat_x` |
| Jerky on large hits | Lower `sat_v` |
| Larger body part, same material | Raise `mass` only — leave everything else |
