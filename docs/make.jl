using Documenter
using DataCurator
Documenter.makedocs(root="./", source="src", build="build", clean=true,
modules=Module[DataCurator], sitename="DataCurator Documentation",
format = Documenter.HTML(prettyurls = false), pages=["Index"=> "index.md", "Installation"=>"installation.md", "Quikstart" => "usage.md","Documented recipe with all features demonstrated"=>"recipe.md", "Conditions and Actions for use in recipes"=>"conditions.md","Remote configuration" => "remote.md", ""=>"extending.md", "API Reference"=> "reference.md"])
#
# deploydocs(
#     repo = "github.com/bencardoen/DataCurator.jl.git",
# )
