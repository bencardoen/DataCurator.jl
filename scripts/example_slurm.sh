#!/bin/bash
#SBATCH --account=[CHANGEME]
#SBATCH --mem=2G
#SBATCH --cpus-per-task=1
#SBATCH --time=0:30:00
#SBATCH --mail-user=[changeme@country.domain]
#SBATCH --mail-type=BEGIN
#SBATCH --mail-type=END
#SBATCH --mail-type=FAIL
#SBATCH --mail-type=REQUEUE
#SBATCH --mail-type=ALL

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
# Copyright 2020-2022, Ben Cardoen

set -euo pipefail

export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK

NOW=$(date +"%m_%d_%Y_HH%I_%M")
echo "Starting setup at $NOW"


NOW=$(date +"%m_%d_%Y_HH%I_%M")

echo "DONE at ${NOW}"
