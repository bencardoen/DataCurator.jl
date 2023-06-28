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

#echo "Assumes you have wget installed"
# This script installs the dependencies for DataCurator on a Mac
echo "Installing wget"
brew install wget

# Test if you're using ARM (M1) or Intel, which will determine which R and Julia to install
USE_M1=0
if [[ $(uname -m) == 'arm64' ]]; then
    echo "You're using M1/M2, arm64 architecture, configuring..."
    USE_M1=1
fi

    
## Testing if R is present
echo "Testing if we can find an existing R installation"
if [ -f "/usr/local/bin/R" ]; then
    echo "R is already installed"
else
    echo "R not found, Installing R"
    if (( $USE_M1 == 1 )); then
        wget https://cloud.r-project.org/bin/macosx/big-sur-arm64/base/R-4.2.3-arm64.pkg
        sudo installer -pkg R-4.2.3-arm64.pkg -target /
    else
        wget https://cran.r-project.org/bin/macosx/base/R-4.2.3.pkg
        sudo installer -pkg R-4.2.3.pkg -target /
    fi
fi

echo "Configuring R path :"
export R_HOME=`R RHOME`
echo $R_HOME
# Install Julia
echo "Installing local Julia 1.8.5 to avoid conflicts with installed versions"
if (( $USE_M1 == 1 )); then
    wget https://julialang-s3.julialang.org/bin/mac/aarch64/1.8/julia-1.8.5-macaarch64.tar.gz && tar -xzf julia-1.8.5-macaarch64.tar.gz
else
    wget https://julialang-s3.julialang.org/bin/mac/x64/1.8/julia-1.8.5-mac64.tar.gz && tar -xzf julia-1.8.5-mac64.tar.gz
fi
cd  julia-1.8.5/bin
export JULIAPATH=`pwd`
export PATH="$PATH:`pwd`"
echo "Updated path to $PATH"

echo "Checking to see if Python 3 is available ..."
# Test if /usr/bin/python3 is available
if [ -f "/usr/bin/python3" ]; then
    echo "Python3 is already installed"
else
    echo "Not found, installing Python3"
    wget https://www.python.org/ftp/python/3.10.10/python-3.10.10-macos11.pkg
    sudo installer -pkg python-3.10.10-macos11.pkg -target /
fi
echo "Setting PYTHON path"
export PYTHON="/usr/bin/python3"
echo $PYTHON
echo "Installing python dependencies"
/usr/bin/pip3 install smlmvis
/usr/bin/pip3 install meshio

echo "Creating local julia env"
cd
mkdir -p test
cd test
echo "Julia environment located in:"
echo `pwd`
# Check that dependencies (Python/R) work
echo "Linking Julia with R and Python"
julia --project=. -e 'using Pkg; Pkg.add("PyCall"); Pkg.add("RCall");'
julia --project=. -e 'using PyCall; pyimport("smlmvis")'
# Add Julia Dependencies
echo "Adding Julia dependencies"
julia --project=. -e 'using Pkg; Pkg.add(url="https://github.com/bencardoen/ERGO.jl.git"); Pkg.add(url="https://github.com/bencardoen/SPECHT.jl.git"); Pkg.add(url="https://github.com/bencardoen/SlurmMonitor.jl.git"); Pkg.add(url="https://github.com/bencardoen/SmlmTools.jl.git");'
# Add DC
# Pkg.add(url="https://github.com/bencardoen/SlurmMonitor.jl.git");Pkg.add(url="https://github.com/bencardoen/ERGO.jl.git"); Pkg.add(url="https://github.com/bencardoen/SPECHT.jl.git"); Pkg.add(url="https://github.com/bencardoen/SmlmTools.jl.git"); Pkg.add(url="https://github.com/bencardoen/DataCurator.jl.git"); Pkg.build("DataCurator"); Pkg.test("DataCurator", coverage=true);'

echo "Adding DataCurator"
julia --project=. -e 'using Pkg; Pkg.add(url="https://github.com/bencardoen/DataCurator.jl.git");' 
# Run tests
echo "Running tests"
julia --project=. -e 'using Pkg; Pkg.test("DataCurator");' 
echo "Done"
echo "Julia environment with DataCurator is installed in `pwd`"
export jenv=`pwd`
echo "Your Julia installation is located in $JULIAPATH"
echo "Update your path to include this"
echo "export PATH=\"$PATH:$JULIAPATH\""
echo "Usage : cd $jenv && julia --project=. -e 'using DataCurator;'"
