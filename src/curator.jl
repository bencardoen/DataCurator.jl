using ArgParse
using DataCurator


function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "--recipe", "-r"
            help = "Recipe in TOML format"
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
        return DataCurator.:proceed
    end
    cfg, template = res
    @info template
    @info cfg
    return delegate(cfg, template)
end

run()
