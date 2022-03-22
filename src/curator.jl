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
# Copyright 2022, Ben Cardoen
using ArgParse
using DataCurator, Images, TOML
using Match
using CSV, DataFrames
using Logging, LoggingExtras, Dates
date_format = "yyyy-mm-dd HH:MM:SS"
timestamp_logger(logger) = TransformerLogger(logger) do log
    merge(log, (; message = "$(Dates.format(now(), date_format)) $(basename(log.file)):$(log.line): $(log.message)"))
end
ConsoleLogger(stdout, Logging.Info) |> timestamp_logger |> global_logger


function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "--recipe", "-r"
            help = "Recipe in TOML format, see example_recipes/ for example configurations"
            arg_type = String
            required = true
    end

    return parse_args(s)
end

function run()
    parsed_args = parse_commandline()
    c = parsed_args["recipe"]
    if ~ isfile(c)
        @error "Failed reading $c, file does not exist"
    end
    res = create_template_from_toml(c)
    if isnothing(res)
        @error "Failed reading $c"
        return :proceed
    end
    cfg, template = res
    c, l, r = delegate(cfg, template)
    @info "Exit status $r"
end

run()
