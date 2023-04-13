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

# Make sure we have current package info
apt-get update -y
# Install tools needed
apt-get install wget git -y
apt install python3 -y
apt install python3-pip -y
# Install Python dependencies
pip3 install smlmvis
pip3 install meshio

echo "Installing Julia"

cd /opt
wget https://julialang-s3.julialang.org/bin/linux/x64/1.8/julia-1.8.5-linux-x86_64.tar.gz
tar zxf julia-1.8.5-linux-x86_64.tar.gz
rm julia-1.8.5-linux-x86_64.tar.gz
export PATH=/opt/julia-1.8.5/bin:$PATH
export JULIA_DEPOT_PATH=/opt/juliadepot
mkdir -p $JULIA_DEPOT_PATH

julia -e 'using Pkg; Pkg.add("Coverage"); Pkg.add(url="https://github.com/bencardoen/SlurmMonitor.jl.git"); Pkg.add(url="https://github.com/bencardoen/SmlmTools.jl.git"); Pkg.add(url="https://github.com/bencardoen/DataCurator.jl.git"); Pkg.build("DataCurator"); Pkg.test("DataCurator", coverage=true);'


julia -e 'using Pkg; cd(Pkg.dir("DataCurator")); using Coverage; if haskey(ENV, "CODECOV_TOKEN") Codecov.submit(Codecov.process_folder()) else @info "No Coverage token, skipping" end'

echo "DataCurator installed in global Julia installation. Usage : julia -e 'using DataCurator;'"
