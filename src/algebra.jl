using Graphs

# Layer types
abstract type AbstractAlgebraic end
abstract type AbstractLayer <: AbstractAlgebraic end

Base.@kwdef struct BaseLayer <: AbstractLayer
    transformation::Function = identity
    graph::Any = nothing
    data::Any = nothing
end

Base.@kwdef struct DataLayer <: AbstractLayer
    transformation::Function = identity
    graph::Any = nothing
    data::Any = nothing
end

Base.@kwdef struct InferLayer <: AbstractLayer
    transformation::Function = identity
    graph::Any = nothing
    subgraphs::Any = nothing
    data::Any = nothing
end

Base.@kwdef struct MatchLayer <: AbstractLayer
    transformation::Function = identity
    graph::Any = nothing
    subgraphs::Any = nothing
    data::Any = nothing
end

Base.@kwdef struct LabelLayer <: AbstractLayer
    transformation::Function = identity
    graph::Any = nothing
    data::Any = nothing
end

Base.@kwdef struct ReduceLayer <: AbstractLayer
    transformation::Function = identity
    graph::Any = nothing
    data::Any = nothing
end

# Collection of layers (a.k.a subgraph decomposition pipeline)
struct LayerCollection <: AbstractAlgebraic
    layers::Vector{AbstractLayer}
end

Base.convert(::Type{LayerCollection}, l::AbstractLayer) = LayerCollection([l])

Base.getindex(layers::LayerCollection, i::Int) = layers.layers[i]
Base.length(layers::LayerCollection) = length(layers.layers)
Base.eltype(::Type{LayerCollection}) = AbstractLayer
Base.iterate(layers::LayerCollection, args...) = iterate(layers.layers, args...)

function Base.:+(a::AbstractAlgebraic, a′::AbstractAlgebraic)
    layers::LayerCollection, layers′::LayerCollection = a, a′
    return LayerCollection(vcat(layers.layers, layers′.layers))
end

function Base.:*(a::AbstractAlgebraic, a′::AbstractAlgebraic)
    layers::LayerCollection, layers′::LayerCollection = a, a′
    return LayerCollection([layer * layer′ for layer in layers for layer′ in layers′])
end


# Inter-layer operations
⨟(f, g) = f === identity ? g : g === identity ? f : (x, y) -> g(f(x, y)...)

function Base.:*(l::T, l′::T) where {T<:AbstractLayer}
    error("Multipliying the same kind of layers is dissallowed")
end

function Base.:*(
    l::Ta,
    l′::Tb,
) where {Ta<:Union{MatchLayer,InferLayer},Tb<:Union{InferLayer,MatchLayer}}
    error("Multiplying layers that generate subgraphs is dissalowed")
end

function Base.:*(l::DataLayer, l′::T) where {T<:Union{InferLayer,MatchLayer}}
    transformation = l.transformation ⨟ l′.transformation
    graph = isnothing(l′.graph) ? l.graph : l′.graph
    data = isnothing(l′.data) ? l.data : l′.data

    return T(graph = graph, transformation = transformation, data = data)
end

function Base.:*(
    l::Ta,
    l′::Tb,
) where {Ta<:Union{InferLayer,MatchLayer},Tb<:Union{LabelLayer,ReduceLayer}}
    transformation = l.transformation ⨟ l′.transformation
    graph = isnothing(l′.graph) ? l.graph : l′.graph
    data = isnothing(l′.data) ? l.data : l′.data

    return Tb(graph = graph, transformation = transformation, data = data)
end

function Base.:*(l::LabelLayer, l′::ReduceLayer)
    transformation = l.transformation ⨟ l′.transformation
    graph = isnothing(l′.graph) ? l.graph : l′.graph
    data = isnothing(l′.data) ? l.data : l′.data

    return ReduceLayer(graph = graph, transformation = transformation, data = data)
end

# API
function data(G::AbstractGraph, data)
    return DataLayer(graph = G, data = data)
end

function infer(ƒ::Function, args...; kwargs...)
    return InferLayer(transformation = (G, data) -> (ƒ(G, args...; kwargs...), data))
end

function match(g::AbstractGraph)
    return MatchLayer(
        transformation = (G, data) -> (
            collect(
                map(
                    p -> first.(p),
                    collect(Graphs.Experimental.all_induced_subgraphisomorph(G, g)),
                ),
            ),
            data,
        ),
    )
end

function label(d::Symbol)
    return LabelLayer(
        transformation = (G, data) -> (collect(map(G) do s
            map(n -> get(data[d], n, missing), s)
        end), data),
    )
end

function reduce(ƒ::Function = hash, args...; kwargs...)
    return ReduceLayer(transformation = (G, data) -> (ƒ(G, args...; kwargs...), data))
end

function compute(L::AbstractLayer)
    return first(L.transformation(L.graph, L.data))
end

function compute(L::LayerCollection)
    return Base.reduce(append!, map(L) do l
        compute(l)
    end, init = [])
end

# Test
G = path_graph(10)
M = (; color = rand([:red, :blue, :yellow], 10), degree = collect(degree(G)))

data(G, M) * match(path_graph(3)) |> compute

data(G, M) * match(path_graph(3)) * label(:color) |> compute

data(G, M) * match(path_graph(3)) * label(:color) * reduce(unique) |> compute

compute(
    data(G, M) * match(path_graph(3)) * (label(:color) + label(:degree)) * reduce(unique),
)
