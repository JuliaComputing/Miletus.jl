using Documenter, Gadfly, Miletus, GraphPlot

load_dir(x) = map(file -> joinpath("lib", x, file), readdir(joinpath(Base.source_dir(), "src", "lib", x)))

makedocs(
    modules = [Miletus],
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true",
        assets = ["assets/jc.css"],
        warn_outdated = true,
        collapselevel=1,
        ),
    sitename = "Miletus",
    pages = Any[
        "Introduction" => "index.md",
        "Tutorial" => "tutorial.md",
        "Examples" => "examples.md",
        "Reference" => "api.md"
    ],
)

