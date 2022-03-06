module DataCurator
using Base.Threads
import Random
import Logging
# Write your package code here.

export topdown, bottomup, expand_filesystem, visit_filesystem, verifier, transformer, logical_and,
verify_template, always, never, warn_on_fail, quit_on_fail, sample, transform_template, quit, proceed, filename, integer_name

quit = :quit
proceed = :proceed
filename = x->basename(x)
integer_name = x->~isnothing(tryparse(Int, filename(x)))
warn_on_fail = x -> @warn "$x"
quit_on_fail = x -> begin @warn "$x"; return :quit; end

function verify_template(start, template; expander=expand_filesystem, traversalpolicy=bottomup, parallel_policy=:sequential)
    return traversalpolicy(start, expander, x->verifier(x, template), 1)
end

always = x->true
never = x->false
sample = x->Random.rand()>0.5

function topdown(node, expander, visitor, level)
    @debug node
    early_exit = visitor(node)
    if early_exit == :quit
        @debug "Early exit triggered"
        return :quit
    end
    nodes = expander(node)
    # @threads
     @threads for _node in nodes
        rv = topdown(_node, expander, visitor, level+1)
        if rv == :quit
            @debug "Early exit triggered"
            return :quit
        end
    end
    return :proceed
end

function bottomup(node, expander, visitor, level)
    nodes = expander(node)
    for _node in nodes
        rv = bottomup(_node, expander, visitor, level+1)
        if rv == :quit
            @debug "Early exit triggered"
            return :quit
        end
    end
    early_exit = visitor(node)
    if early_exit == :quit
        @debug "Early exit triggered"
        return :quit
    else
        return :proceed
    end
end


function expand_filesystem(node)
    return isdir(node) ? readdir(node, join=true) : []
end

## Expand mat
## isdict, else variable

## Expand HDF5

function visit_filesystem(node)
    @info node
end

function transform_template(start, template; expander=expand_filesystem, traversalpolicy=bottomup, parallel_policy=:sequential)
    traversalpolicy(start, expander, x->transformer(x, template), 1)
end

function verifier(node, template)
    for (condition, onfail) in template
        if condition(node) == false
            rv = onfail(node)
            if rv == :quit
                return :quit
            end
        end
    end
end

function verifier_hierarchical(node, template; level=1)
    if haskey(template, level)
        level_conditions = template[level]
        @info "Applying $(length(level_conditions)) to $level"
        for (condition, onfail) in level_conditions
            if condition(node) == false
                rv = onfail(node)
                if rv == :quit
                    return :quit
                end
            end
        end
    end
end

function transformer(node, template)
    # @warn "X"
    for (condition, action) in template
        if condition(node)
            rv = action(node)
            if rv == :quit
                return :quit
            end
            node = isnothing(rv) ? node : rv
        end
    end
end

logical_and = (x, conditions) -> all(c(x) for c in conditions)

end
