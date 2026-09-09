using LinearAlgebra
using StaticArrays
using GLMakie

function flattenRays(rays)

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

function drawScene(flattened_rays)

    fig = Figure(size=(900, 700))

    ax = Axis3(
        fig[1, 1],
        title="Ray-Sphere Interaction",
        xlabel="X Axis",
        ylabel="Y Axis",
        zlabel="Z Axis",

        # 1. Fix aspect ratio so 1 unit in X = 1 unit in Y = 1 unit in Z (spheres stay circular)
        aspect=:data,

        # 2. Disable dynamic box resizing/pumping during rotation
        viewmode=:fit,

        # 3. Lock axis boundaries so GLMakie won't auto-rescale
        limits=(-5, 5, -5, 5, -1, 6),

        # Optional: Set perspective strength (0.0 = completely flat orthographic view)
        perspectiveness=0.5
    )

    # Draw all 10,000 rays in 1 draw call
    lines!(ax, flattened_rays, color=:orange, linewidth=0.5, alpha=0.3)

    # Draw Sphere surface
    mesh!(ax, Sphere(sphere_obj.center, sphere_obj.radius), color=(:cyan, 0.4), transparency=false)

    # Draw Light Source
    meshscatter!(ax, [Point3f(LIGHT_SOURCE...)], color=:yellow, markersize=0.2)

    display(fig)
    readline()
    GLMakie.closeall()

end
