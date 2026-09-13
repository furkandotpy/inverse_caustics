using LinearAlgebra
using StaticArrays
using GLMakie

include("structs.jl")

function flattenRays(rays::Vector{Ray})::Vector{Point3f}

    # 2. Build flat vector of points connected by NaNs (Single draw-call)
    flattened_rays = Vector{Point3f}(undef, length(rays) * 3)
    @inbounds for (i, r) in enumerate(rays)
        p_start = Point3f(r.origin...)
        p_end = Point3f((r.origin .+ r.direction .* ray_length)...)

        idx = 3 * (i - 1)
        flattened_rays[idx+1] = p_start
        flattened_rays[idx+2] = p_end
        flattened_rays[idx+3] = Point3f(NaN, NaN, NaN) # Breaks the line segment
    end
    return flattened_rays
end

function collect_intersections(rays::Vector{Ray}, sphere_obj::OpticalSphere)
    intersections = Point3f[]

    for r in rays
        t = ray_sphere_intersection(r, sphere_obj.center, sphere_obj.radius)
        if !isnothing(t)
            # Calculate point: origin + direction * distance
            p_hit = Point3f(r.origin .+ r.direction .* t)
            push!(intersections, p_hit)
        end
    end

    return intersections
end

function drawScene(flattened_rays::Vector{Point3f}, hit_points::Vector{Point3f})
    fig = Figure(size=(900, 700))

    ax = Axis3(
        fig[1, 1],
        title="Ray-Sphere Interaction",
        xlabel="X Axis", ylabel="Y Axis", zlabel="Z Axis",
        aspect=:data,
        viewmode=:fit,
        limits=(-5, 5, -5, 5, -1, 6),
        perspectiveness=0.5
    )

    # Draw Rays
    lines!(ax, flattened_rays, color=:orange, linewidth=0.5, alpha=0.3)

    # Draw Sphere surface
    mesh!(ax, Sphere(sphere_obj.center, sphere_obj.radius), color=(:cyan, 0.4), transparency=false)

    # Draw Light Source
    meshscatter!(ax, [Point3f(LIGHT_SOURCE...)], color=:yellow, markersize=0.2)

    # Draw Intersection Points
    if !isempty(hit_points)
        meshscatter!(ax, hit_points, color=:red, markersize=0.08)
    end

    display(fig)
    readline()
    GLMakie.closeall()
end
