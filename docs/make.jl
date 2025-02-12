# Show number of threads on GitHub Actions
@info "" Threads.nthreads()

# Look for environment variable triggering local development modifications
localdev = haskey(ENV, "LOCALDEV")
@show localdev

# Get access to example dependencies
push!(LOAD_PATH, joinpath(@__DIR__, "..", "examples"))

using IncompressibleNavierStokes
using NeuralClosure
using Literate
using Documenter
using DocumenterCitations
using DocumenterVitepress

DocMeta.setdocmeta!(
    IncompressibleNavierStokes,
    :DocTestSetup,
    :(using IncompressibleNavierStokes);
    recursive = true,
)

bib = CitationBibliography(joinpath(@__DIR__, "references.bib"))

makemarkdown(inputfile, outputdir; run) =
    if run
        # With code execution blocks
        Literate.markdown(inputfile, outputdir)
    else
        # Turn off code execution.
        # Note: Literate has a `documenter = false` option, but this would also remove
        # the "Edit on GitHub" button at the top, therefore we disable the `@example`-blocks
        # manually
        Literate.markdown(
            inputfile,
            outputdir;
            preprocess = content ->
                "# *Note: Output is not generated for this example (to save resources on GitHub).*\n\n" *
                content,
            postprocess = content -> replace(content, r"@example.*" => "julia"),
        )
    end

# Generate examples
e = "examples"
examples = [
    "Simple flows" => [
        (true, "examples/DecayingTurbulence2D", "Decaying Turbulunce (2D)"),
        (false, "examples/DecayingTurbulence3D", "Decaying Turbulunce (3D)"),
        (true, "examples/TaylorGreenVortex2D", "Taylor-Green Vortex (2D)"),
        (false, "examples/TaylorGreenVortex3D", "Taylor-Green Vortex (3D)"),
        (false, "examples/ShearLayer2D", "Shear Layer (2D)"),
        (false, "examples/PlaneJets2D", "Plane jets (2D)"),
    ],
    "Mixed boundary conditions" => [
        (true, "examples/Actuator2D", "Actuator (2D)"),
        (false, "examples/Actuator3D", "Actuator (3D)"),
        (false, "examples/BackwardFacingStep2D", "Backward Facing Step (2D)"),
        (false, "examples/BackwardFacingStep3D", "Backward Facing Step (3D)"),
        (false, "examples/LidDrivenCavity2D", "Lid-Driven Cavity (2D)"),
        (false, "examples/LidDrivenCavity3D", "Lid-Driven Cavity (3D)"),
        (false, "examples/MultiActuator", "Multiple actuators (2D)"),
        (false, "examples/PlanarMixing2D", "Planar Mixing (2D)"),
    ],
    "With temperature field" => [
        (true, "examples/RayleighBenard2D", "Rayleigh-Bénard (2D)"),
        (false, "examples/RayleighBenard3D", "Rayleigh-Bénard (3D)"),
        (true, "examples/RayleighTaylor2D", "Rayleigh-Taylor (2D)"),
        (false, "examples/RayleighTaylor3D", "Rayleigh-Taylor (3D)"),
    ],
    "Neural closure models" => [
        (false, "lib/PaperDC/prioranalysis", "Filter analysis"),
        (false, "lib/PaperDC/postanalysis", "CNN closures"),
        (false, "lib/SymmetryClosure/symmetryanalysis", "Equivariant closures"),
    ],
]

# Convert scripts to executable markdown files
output = "examples/generated"
outputdir = joinpath(@__DIR__, "src", output)
## rm(outputdir; recursive = true)
for e ∈ examples, (run, name, title) ∈ e[2]
    inputfile = joinpath(@__DIR__, "..", name * ".jl")
    makemarkdown(inputfile, outputdir; run)
end

example_pages = map(examples) do e
    e[1] => map(e[2]) do (run, name, title)
        title => joinpath(output, basename(name) * ".md")
    end
end

vitepress_kwargs = localdev ? (;
    # md_output_path = @__DIR__,
    build_vitepress = false
) : (;)

makedocs(;
    # draft = true,
    # clean = !localdev,
    modules = [IncompressibleNavierStokes, NeuralClosure],
    plugins = [bib],
    authors = "Syver Døving Agdestein, Benjamin Sanderse, and contributors",
    repo = Remotes.GitHub("agdestein", "IncompressibleNavierStokes.jl"),
    sitename = "IncompressibleNavierStokes.jl",
    # format = Documenter.HTML(;
    #     prettyurls = get(ENV, "CI", "false") == "true",
    #     canonical = "https://agdestein.github.io/IncompressibleNavierStokes.jl",
    #     assets = String[],
    # ),
    format = DocumenterVitepress.MarkdownVitepress(;
        repo = "github.com/agdestein/IncompressibleNavierStokes.jl",
        devurl = "dev",
        vitepress_kwargs...,
    ),
    pagesonly = true,
    pages = [
        "Home" => "index.md",
        "Getting Started" => "getting_started.md",
        "Examples" => vcat("Overview" => "examples/index.md", example_pages),
        "Manual" => [
            "Incompressible Navier-Stokes equations" => "manual/ns.md",
            "Spatial discretization" => "manual/spatial.md",
            "Time discretization" => "manual/time.md",
            "Boundary conditions" => "manual/bc.md",
            "Pressure solvers" => "manual/pressure.md",
            "Floating point precision" => "manual/precision.md",
            "GPU Support" => "manual/gpu.md",
            "Operators" => "manual/operators.md",
            "Temperature equation" => "manual/temperature.md",
            "Large eddy simulation" => "manual/les.md",
            "Neural closure models" => "manual/closure.md",
            "API" => "manual/api.md",
        ],
        "References" => "references.md",
    ],
)

# Only deploy docs on CI
get(ENV, "CI", "false") == "true" && deploydocs(;
    repo = "github.com/agdestein/IncompressibleNavierStokes.jl",
    target = "build",
    devbranch = "main",
    push_preview = true,
)
