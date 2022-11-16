using Pkg
Pkg.activate(".")
Pkg.add(url="https://github.com/bencardoen/SlurmMonitor.jl.git")
Pkg.add(url="https://github.com/bencardoen/DataCurator.jl.git")
Pkg.build("DataCurator")
Pkg.test("DataCurator")

