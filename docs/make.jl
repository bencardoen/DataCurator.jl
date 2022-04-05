using Documenter
using DataCurator
Documenter.makedocs(root="./", source="src", build="build", clean=true,
modules=Module[DataCurator], sitename="DataCurator Documentation",
format = Documenter.HTML(prettyurls = false), pages=["Index"=> "index.md",
"Installation"=>"installation.md", "Documented recipe with all features"=>"documented_recipe.md",
"API Reference"=> "reference.md", "Conditions and Actions for use in recipes"=>"conditions.md",])

deploydocs(
    repo = "github.com/bencardoen/DataCurator.jl.git",
)
