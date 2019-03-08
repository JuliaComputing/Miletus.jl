using Documenter, Gadfly, Miletus, GraphPlot

load_dir(x) = map(file -> joinpath("lib", x, file), readdir(joinpath(Base.source_dir(), "src", "lib", x)))

makedocs(
    modules = [Miletus],
    clean = false,
    format = [:html, :latex],
    sitename = "JuliaFin∕Miletus",
    pages = Any[
        "Introduction" => "index.md",
        "Tutorial" => "tutorial.md",
        "Examples" => "examples.md"
    ],
    assets = ["assets/jc.css"]
)

deploydocs(
    repo   = "github.com/JuliaComputing/Miletus.jl.git",
    julia  = "0.5",
    osname = "linux",
    deps = nothing,
    make = nothing,
    target = "build",
)
