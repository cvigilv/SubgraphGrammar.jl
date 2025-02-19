using Graphs

abstract type AbstractSubgraph{T<:AbstractGraph} <: AbstractGraph{eltype(T)} end

# Base struct for subgraphs
struct Subgraph{T<:AbstractGraph} <: AbstractSubgraph{T}
    graph::T
    nodes::Vector{Int}
    edges::Vector{Edge}
end

# InferredSubgraph
struct InferredSubgraph{T<:AbstractGraph} <: AbstractSubgraph{T}
    subgraph::Subgraph{T}
    root::Int
end

# DefinedSubgraph
struct DefinedSubgraph{T<:AbstractGraph} <: AbstractSubgraph{T}
    subgraph::Subgraph{T}
    name::String
end

# LabeledSubgraph
struct LabeledSubgraph{T<:AbstractSubgraph}
    subgraph::T
    label::String
end
