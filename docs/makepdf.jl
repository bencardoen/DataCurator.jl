using Documenter
using DataCurator
Documenter.makedocs(root=".", build="/home/bcardoen/SFUVault/repositories/DataCurator.jl/docs/build", clean=true,
modules=Module[DataCurator], sitename="DataCurator Documentation",
format = Documenter.LaTeX(), pages=["Index"=> "index.md", "Installation"=>"installation.md", "Quikstart" => "usage.md","Documented recipe with all features demonstrated"=>"recipe.md", "Conditions and Actions for use in recipes"=>"conditions.md","API Reference"=> "reference.md"])
# "Documented recipe with all features"=>"documented_recipe.md"])
# ,"API Reference"=> "reference.md", "Conditions and Actions for use in recipes"=>"conditions.md"])

# deploydocs(
#     repo = "github.com/bencardoen/DataCurator.jl.git",
# )
# format = Documenter.LaTeX(), pages=["Index"=> "index.md",
# "Installation"=>"installation.md", "Documented recipe with all features"=>"documented_recipe.md",
# "API Reference"=> "reference.md", "Conditions and Actions for use in recipes"=>"conditions.md",])
