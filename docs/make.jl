using SubgraphGrammar
using Documenter

DocMeta.setdocmeta!(
    SubgraphGrammar,
    :DocTestSetup,
    :(using SubgraphGrammar);
    recursive = true,
)

const page_rename = Dict("developer.md" => "Developer docs") # Without the numbers
const numbered_pages = [
    file for file in readdir(joinpath(@__DIR__, "src")) if
    file != "index.md" && splitext(file)[2] == ".md"
]

makedocs(;
    modules = [SubgraphGrammar],
    authors = "Carlos Vigil-Vásquez <carlos.vigil.v@gmail.com>",
    repo = "https://github.com/cvigilv/SubgraphGrammar.jl/blob/{commit}{path}#{line}",
    sitename = "SubgraphGrammar.jl",
    format = Documenter.HTML(; canonical = "https://cvigilv.github.io/SubgraphGrammar.jl"),
    pages = ["index.md"; numbered_pages],
)

deploydocs(; repo = "github.com/cvigilv/SubgraphGrammar.jl")
