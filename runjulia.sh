#!/bin/bash

export LOCALPKG=/opt/DataCurator.jl
    #/opt/julia/julia-1.6.2/bin
export JLMJV=1.6
export JLV=$JLMJV.2
export PATH=/opt/julia/julia-$JLV/bin:$PATH
export JULIA_DEPOT_PATH=/opt/juliadepot
echo "BEGIN"
echo "First arg is $1"
julia --project=/opt/DataCurator.jl /opt/DataCurator.jl/src/curator.jl --recipe $1
echo "END"
echo "First arg is $1"
