module DataCurator
using Base.Threads
import Random
import Logging
# Write your package code here.

export topdown, bottomup, expand_filesystem, visit_filesystem, verifier, transformer, logical_and,
verify_template, always, never, sample, transform_template

function verify_template(start, template; expander=expand_filesystem, traversalpolicy=bottomup, parallel_policy=:sequential)
    traversalpolicy(start, expander, x->verifier(x, template), 1)
end

always = x->true
never = x->false
sample = x->Random.rand()>0.5

function topdown(node, expander, visitor, level)
    @debug node
    visitor(node)
    nodes = expander(node)
    @threads for _node in nodes
        topdown(_node, expander, visitor, level+1)
    end
end

function bottomup(node, expander, visitor, level)
    nodes = expander(node)
    @threads for _node in nodes
        bottomup(_node, expander, visitor, level+1)
    end
    visitor(node)
end

function expand_filesystem(node)
    if isdir(node)
        return readdir(node, join=true)
    else
        return []
    end
end

function visit_filesystem(node)
    @info node
end

function transform_template(start, template; expander=expand_filesystem, traversalpolicy=bottomup, parallel_policy=:sequential)
    traversalpolicy(start, expander, x->transformer(x, template), 1)
end


function verifier(node, template)
    for (condition, onfail) in template
        if ~condition(node)
            onfail(node)
        end
    end
end

function transformer(node, template)
    # @warn "X"
    for (condition, action) in template
        if condition(node)
            x = action(node)
            node = isnothing(x) ? node : x
        end
    end
end

logical_and = (x, conditions) -> all(c(x) for c in conditions)

end
