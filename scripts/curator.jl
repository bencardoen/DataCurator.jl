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
using SlurmMonitor
using Printf
using Dates
# date_format = "yyyy-mm-dd HH:MM:SS"
# timestamp_logger(logger) = TransformerLogger(logger) do log
#     merge(log, (; message = "$(Dates.format(now(), date_format)) $(basename(log.file)):$(log.line): $(log.message)"))
# end
# ConsoleLogger(stdout, Logging.Info) |> timestamp_logger |> global_logger


function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "--recipe", "-r"
            help = "Recipe in TOML format, see example_recipes/ for example configurations"
            arg_type = String
            required = true
        "--verbose", "-v"
            help = "Set logging level to Debug (default Info). Only useful for debugging purposes, for large datasets this can produce huge output."
            action = :store_true
        "--quiet", "-q"
            help = "Set logging level to warn only, e.g. only when things go wrong. You won't be informed if your template or validation succeeded."
            action = :store_true
        "--inputdirectory"
            help = "If you want to override the inputdirectory field of the recipe at runtime, use this."
            arg_type = String
            default = ""
        "--endpoint", "-e"
            help = "File containing Slack endpoint of the form /services/<x>/<y>/<id>"
	    	arg_type = String
	    	default = ""
    end

    return parse_args(s)
end


function update_template(template, indir, outdir)
    @info "Updating global configuration with $indir and $outdir"
    ENV["DC_inputdirectory"] = indir
    ENV["DC_outputdirectory"] = outdir
    return template
end

function runme()
    parsed_args = parse_commandline()
    defl = Logging.Info
    v = parsed_args["verbose"]
    if v
        defl = Logging.Debug
    end
    q = parsed_args["quiet"]
    if q
        defl = Logging.Warn
    end
    date_format = "yyyy-mm-dd HH:MM:SS"
    timestamp_logger(logger) = TransformerLogger(logger) do log
        merge(log, (; message = "$(Dates.format(now(), date_format)) $(basename(log.file)):$(log.line): $(log.message)"))
    end
    ConsoleLogger(stdout, defl) |> timestamp_logger |> global_logger
	endpoint = nothing
	if parsed_args["endpoint"] != ""
    	endpoint = readendpoint(parsed_args["endpoint"])
		if isnothing(endpoint)
			@error "Failed decoding Slack endpoint!!!"
		end
    	@info "Using endpoint $endpoint"
	end
    recipe = parsed_args["recipe"]
    if ~ isfile(recipe)
        @error "Failed reading $recipe, file does not exist"
		return
    end
    if parsed_args["inputdirectory"] != ""
        @info "Overriding template inputdirectory with $(parsed_args["inputdirectory"])"
        recipe = update_template(recipe, parsed_args["inputdirectory"], nothing)
    end
    @info "Reading template recipe $recipe"
    res = create_template_from_toml(recipe)
    if isnothing(res)
        @error "Failed reading $c"
        return
    end
    @info "✓ Reading complete ✓"
    cfg, template = res
    @info "Running recipe on $(cfg["inputdirectory"])"
	if cfg["endpoint"] == "" && !isnothing(endpoint)
		@info "Overriding endpoint with slack $endpoint"
		cfg["endpoint"] = endpoint
	end
	if isnothing(endpoint) && cfg["endpoint"] != ""
		@info "using template endpoint"
		endpoint = cfg["endpoint"]
	end
	start=time()
    c, l, r = delegate(cfg, template)
	stop=time()
    df=DataFrames.DataFrame(name = String[], count=Float64[])
    for (cn, _c) in enumerate(c)
        @info "Counter $cn --> $(_c)"
        push!(df, [_c[1], Float64.(_c[2])])
    end
	if r == :proceed && cfg["at_exit"] != ""
		@info "Calling exit script"
		if cfg["at_exit"][1] == "schedule_script"
			finisher =  x -> lookup("schedule_script")(x)
			finisher(cfg["at_exit"][2])
		else
			@warn "Unsupported at exit action $(cfg["at_exit"])"
		end
	end

	neatcode = r == :proceed ? ":white_check_mark: Success" : ":octagonal_sign: Stopped"
	@info "Writing counters to counters.csv"
    CSV.write("counters.csv", df)
	date_format = "yyyy-mm-dd HH:MM:SS"
	msgs = ["DataCurator :construction_worker:", ":clock3: \t $(Dates.format(now(), date_format))", "Recipe \t $recipe", "Result \t $neatcode", ":stopwatch: \t $(@sprintf("%.2e",stop-start)) seconds"]
	if ! isnothing(endpoint)
        @info "Posting to Slack"
		m = ":computer: \t $(readlines(`uname -nir`)[1])"
		push!(msgs, m)
		for (cn, _c) in enumerate(c)
			push!(msgs, "Counter $(_c[1]) has value \t $(@sprintf("%.2e",_c[2]))")
        end
		posttoslack(join(msgs, "\n"), endpoint)
    end
	@info "🏁✓ Complete with exit status $r ✓🏁"
	delete!(ENV, "DC_SSH_CONFIG")
	delete!(ENV, "DC_owncloud_configuration")
end

runme()
