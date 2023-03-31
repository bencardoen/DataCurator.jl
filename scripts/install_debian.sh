#!/bin/bash

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
# Copyright 2023, Ben Cardoen

set -xeuo pipefail

echo "Assumes you have wget installed"
# This script installs the dependencies for DataCurator on a debian (apt) based system
# Uses a prebuilt image with Julia (see CircleCI), 1.8
# Assumes to be run with sudo or as root (see CircleCI)

## Set to python which we will install, and install R inside DC
export R_HOME="*"
export PYTHON="/usr/bin/python3"

# apt-get update -y
# apt-get install wget -y
apt install python3 -y
apt install python3-pip -y
pip3 install smlmvis
pip3 install meshio


julia -e 'using Pkg; Pkg.add("Coverage"); Pkg.add(url="https://github.com/bencardoen/SlurmMonitor.jl.git"); Pkg.add(url="https://github.com/bencardoen/SmlmTools.jl.git"); Pkg.add(url="https://github.com/bencardoen/DataCurator.jl.git"); Pkg.build("DataCurator"); Pkg.test("DataCurator", coverage=true);'


julia -e 'using Pkg; cd(Pkg.dir("DataCurator")); using Coverage; if haskey(ENV, "CODECOV_TOKEN") Codecov.submit(Codecov.process_folder()) else @info "No Coverage token, skipping" end'

echo "DataCurator installed in global Julia installation. Usage : julia -e 'using DataCurator;'"