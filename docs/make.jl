using OPFLearn
using Documenter

DocMeta.setdocmeta!(OPFLearn, :DocTestSetup, :(using OPFLearn); recursive=true)

makedocs(;
    modules=[OPFLearn],
    authors="Trager Joswig-Jones",
    sitename="OPFLearn",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://NREL.github.io/OPFLearn.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
		"Manual" => [
		"Getting Started" => "quickstartguide.md",
		"OPFLearn Framework" => "framework.md",
		"Result Data" => "results.md",
		"Dataset Format" => "dataset.md",
		"Distributed Processing" => "distributed.md",
		"Python Interface" => "python.md",
		],
		"Library" => [
		"Dataset Creation" => "datasetcreation.md",
		"Exporting Datasets" => "saving.md",
		"Sampling" => "sampling.md"
		]
    ],
)

deploydocs(;
    repo="github.com/NREL/OPFLearn.jl.git",
    devbranch = "main"
)
