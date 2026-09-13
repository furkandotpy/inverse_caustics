using LinearAlgebra
using StaticArrays
using Rotations
using GLMakie
using Colors
using Base.Threads
using ProgressMeter
using InteractiveUtils

# --- Data Structures ---

struct Ray
    position::SVector{3, Float32}
    direction::SVector{3, Float32}

    @inline function Ray(position, direction)
        dir = normalize(SVector{3, Float32}(direction))
        new(position, dir)
    end
end

struct SphereObject
    center::SVector{3, Float32}
    radius::Float32
    IOR::Float32
    id::Int64
end

struct CuboidObject
    center::SVector{3, Float32}
    half_size::SVector{3, Float32}
    rotation::SMatrix{3, 3, Float32, 9}
    IOR::Float32
    id::Int

    function CuboidObject(center, size, rotation, IOR=0.0f0, id=0)
        c = SVector{3, Float32}(center)
        hs = SVector{3, Float32}(size) ./ 2.0f0
        rot = SMatrix{3, 3, Float32, 9}(rotation)
        new(c, hs, rot, Float32(IOR), id)
    end
end

struct PlaneObject
    center::SVector{3, Float32}
    rotation::SMatrix{3, 3, Float32, 9}
    width::Float32
    height::Float32
    id::Int
end

struct Camera
    position::SVector{3, Float32}
    orientation::SVector{3, Float32}
    image_plane_distance::Float32
    image_dimensions::SVector{2, Float32}
    image_resolution::SVector{2, Int}
    image_plane_midpoint::SVector{3, Float32}
    image_plane_right::SVector{3, Float32}
    image_plane_up::SVector{3, Float32}

    function Camera(position, orientation, distance, dimensions, resolution)
        pos = SVector{3, Float32}(position)
        orient = normalize(SVector{3, Float32}(orientation))
        dims = SVector{2, Float32}(dimensions)
        res = SVector{2, Int}(resolution)

        world_up = SVector(0.0f0, 0.0f0, -1.0f0)
        if abs(dot(orient, world_up)) > 0.999f0
            world_up = SVector(0.0f0, 0.0f0, 1.0f0)
        end

        right = normalize(cross(orient, world_up))
        up = normalize(cross(right, orient))
        midpoint = pos + orient * distance

        new(pos, orient, distance, dims, res, midpoint, right, up)
    end
end

struct LightSource
    position::SVector{3, Float32}
end

# --- Material System ---

@inline function get_material_color(id::Int)
    if id == 1
        return RGB{Float32}(0.0f0, 1.0f0, 0.0f0) # Sphere (Green)
    elseif id == 2
        return RGB{Float32}(1.0f0, 1.0f0, 0.0f0) # Box (Yellow)
    elseif id == 3
        return RGB{Float32}(0.2f0, 0.5f0, 0.9f0) # PlaneObject (Blue)
    end
    return RGB{Float32}(0.5f0, 0.5f0, 0.5f0)
end

# --- CSG & SDF System ---

abstract type SDFNode end

struct Primitive{T} <: SDFNode
    object::T
end

struct CSGUnion{A<:SDFNode, B<:SDFNode} <: SDFNode
    a::A
    b::B
end

struct CSGIntersection{A<:SDFNode, B<:SDFNode} <: SDFNode
    a::A
    b::B
end

struct CSGDifference{A<:SDFNode, B<:SDFNode} <: SDFNode
    a::A
    b::B
end

@inline sdf(p, node::Primitive) = sdf(p, node.object)

@inline function sdf(p::SVector{3, Float32}, sphere::SphereObject)
    d = norm(p - sphere.center) - sphere.radius
    return (d, sphere.id)
end

@inline function sdf(p::SVector{3, Float32}, cuboid::CuboidObject)
    p_local = cuboid.rotation' * (p - cuboid.center)
    q = abs.(p_local) .- cuboid.half_size

    max_q = max(q[1], max(q[2], q[3]))
    
    outside = norm(max.(q, 0.0f0))
    inside = min(max_q, 0.0f0)
    return (outside + inside, cuboid.id)
end

@inline function sdf(p::SVector{3, Float32}, plane::PlaneObject)
    p_local = plane.rotation' * (p - plane.center)
    dx = max(abs(p_local[1]) - plane.width / 2.0f0, 0.0f0)
    dy = max(abs(p_local[2]) - plane.height / 2.0f0, 0.0f0)
    d = norm(SVector(dx, dy, p_local[3]))
    return (d, plane.id)
end

@inline function sdf(p, u::CSGUnion)
    d1, id1 = sdf(p, u.a)
    d2, id2 = sdf(p, u.b)
    return d1 < d2 ? (d1, id1) : (d2, id2)
end

@inline function sdf(p, i::CSGIntersection)
    d1, id1 = sdf(p, i.a)
    d2, id2 = sdf(p, i.b)
    return d1 > d2 ? (d1, id1) : (d2, id2)
end

@inline function sdf(p, d::CSGDifference)
    d1, id1 = sdf(p, d.a)
    d2, id2 = sdf(p, d.b)
    d_out = max(d1, -d2)
    id = -d2 > d1 ? id2 : id1
    return (d_out, id)
end

to_sdf(node::SDFNode) = node
to_sdf(obj)           = Primitive(obj)

function buildScene(objects...)
    return foldl(CSGUnion, map(to_sdf, objects))
end

# --- Camera & Ray Generation ---

@inline function get_ray(camera::Camera, x::Int, y::Int)
    width, height = camera.image_dimensions
    res_x, res_y = camera.image_resolution

    pixel_width = width / res_x
    pixel_height = height / res_y

    x_offset = (x - 0.5f0 - res_x / 2.0f0) * pixel_width
    y_offset = (y - 0.5f0 - res_y / 2.0f0) * pixel_height

    target_pt = camera.image_plane_midpoint +
                x_offset * camera.image_plane_right +
                y_offset * camera.image_plane_up

    dir = normalize(target_pt - camera.position)
    return Ray(camera.position, dir)
end

@inline function sky_color(dir::SVector{3, Float32})
    t = 0.5f0 * dir[3] + 0.5f0
    horizon = RGB{Float32}(0.85f0, 0.9f0, 1.0f0)
    zenith  = RGB{Float32}(0.15f0, 0.4f0, 0.9f0)
    return (1.0f0 - t) * horizon + t * zenith
end

@inline function softshadow(origin::SVector{3, Float32}, dir::SVector{3, Float32}, scene; k=16.0f0, min_t=0.02f0, max_t=10.0f0)
    res = 1.0f0
    t = min_t
    
    for _ in 1:32
        h, _ = sdf(origin + t * dir, scene)
        
        if h < 1e-4
            return 0.0f0 # Fully occluded
        end
        
        y = h * h / (2.0f0 * t)
        d = sqrt(max(0.0f0, h * h - y * y))
        res = min(res, k * d / max(0.0f0, t - y))
        
        t += clamp(h, 0.001f0, 0.2f0)
        
        if t > max_t
            break
        end
    end
    
    res = clamp(res, 0.0f0, 1.0f0)
    return res * res * (3.0f0 - 2.0f0 * res) 
end

# --- Raymarching Engine ---

@inline function raymarching_step(ray::Ray, scene; max_steps=100, hit_epsilon=1e-5, max_distance=1000.0f0)
    t = 0.0f0
    for _ in 1:max_steps
        current_pos = ray.position + t * ray.direction
        dist, id = sdf(current_pos, scene)

        if dist < hit_epsilon
            return (current_pos, id)
        end

        t += dist
        if t > max_distance
            break
        end
    end
    return (SVector{3, Float32}(Inf32, Inf32, Inf32), 0)
end

# --- Execution ---

camera = Camera(
    SVector(0.0f0, 5.0f0, 5.0f0), 
    SVector(0.0f0, -1.0f0, -1.0f0),
    1.0f0,
    SVector(2.0f0, 2.0f0),
    SVector(1000, 1000)
)

sphere = Primitive(SphereObject(SVector(1.0f0, 1.0f0, 1.0f0), 1.0f0, 2.0f0, 1))
plane  = Primitive(PlaneObject(SVector(0.0f0, 0.0f0, -0.5f0), SMatrix{3,3,Float32,9}(RotXY(0.0f0, 0.0f0)), 10.0f0, 10.0f0, 3))

scene = buildScene(sphere, plane)

res_x, res_y = camera.image_resolution
framebuffer = zeros(RGB{Float32}, res_x, res_y)

function render_scene!(framebuffer, scene, camera, light_source)
    res_x, res_y = camera.image_resolution
    
    Threads.@threads for y in 1:res_y
        @inbounds for x in 1:res_x
            ray = get_ray(camera, x, y)
            hitpoint, hit_id = raymarching_step(ray, scene)
            
            if hit_id != 0
                base_color = get_material_color(hit_id)
                L = normalize(light_source.position - hitpoint)
                
                shadow_factor = softshadow(hitpoint + L * 1e-3, L, scene; k=16.0f0)
                color = base_color * (0.15f0 + 0.85f0 * shadow_factor)
            else
                color = sky_color(ray.direction)
            end
            
            framebuffer[x, res_y - y + 1] = color
        end
    end
end

img_obs = Observable(copy(framebuffer))
fig, ax, plt = image(img_obs, axis = (aspect = DataAspect(), title = "Animated Scene"))
screen = display(fig)

num_frames = 120
fps = 30
p = Progress(num_frames; desc="Rendering Video: ", barlen=30)

record(fig, "raymarched_scene.mp4", 1:num_frames; framerate = fps) do frame_idx
    t = Float32(frame_idx) * 0.05f0
    moving_light = LightSource(SVector(5.0f0 * cos(t), 5.0f0 * sin(t), 4.0f0))
    
    render_scene!(framebuffer, scene, camera, moving_light)
    img_obs[] = framebuffer
    
    next!(p)
end
