"""
CPU-first neural evaluation for JuliaChess.

The default constructor creates an untrained model. Its scores are useful for
testing the inference pipeline, but they are not meaningful chess evaluations
until trained weights are loaded.

# Example

```julia
include("src/NNUE.jl")
using .NNUE
using Chess

model = NNUEModel()
score = nnue_evaluate(model, startboard())

save_nnue("untrained-weights.jld2", model)
loaded_model = load_nnue("untrained-weights.jld2")
```

The save/load lines demonstrate the weight-file API; the resulting model
remains untrained.
"""
module NNUE

using Chess
using Flux
using JLD2
using Random

export FEATURE_COUNT,
    NNUEModel,
    accumulator,
    active_feature_indices,
    feature_index,
    load_nnue,
    nnue_evaluate,
    save_nnue

const FEATURES_PER_COLOR = 6 * 64
const FEATURE_COUNT = 2 * FEATURES_PER_COLOR
const FILE_FORMAT_VERSION = 1
const ARCHITECTURE_NAME = "piece-square-accumulator-v1"

clipped_relu(x) = clamp(x, 0f0, 1f0)

"""
    NNUEModel(; accumulator_dim=128, hidden_dim=32, rng=Random.default_rng())

Construct an untrained NNUE model. Piece-square embeddings feed two
perspective accumulators, followed by a small dense output network.
"""
struct NNUEModel{H,O}
    feature_weights::Matrix{Float32}
    feature_bias::Vector{Float32}
    hidden::H
    output::O
end

Flux.@layer NNUEModel

function initialized_weights(rng::AbstractRNG, rows::Int, columns::Int)
    limit = sqrt(Float32(6) / Float32(rows + columns))
    return (2f0 .* rand(rng, Float32, rows, columns) .- 1f0) .* limit
end

function NNUEModel(;
    accumulator_dim::Int = 128,
    hidden_dim::Int = 32,
    rng::AbstractRNG = Random.default_rng(),
)
    accumulator_dim > 0 || throw(ArgumentError("accumulator_dim must be positive"))
    hidden_dim > 0 || throw(ArgumentError("hidden_dim must be positive"))

    feature_weights = initialized_weights(rng, accumulator_dim, FEATURE_COUNT)
    feature_bias = zeros(Float32, accumulator_dim)
    hidden_weights = initialized_weights(rng, hidden_dim, 2 * accumulator_dim)
    output_weights = initialized_weights(rng, 1, hidden_dim)

    hidden = Dense(hidden_weights, zeros(Float32, hidden_dim), clipped_relu)
    output = Dense(output_weights, zeros(Float32, 1))
    return NNUEModel(feature_weights, feature_bias, hidden, output)
end

function perspective_square_index(square::Square, perspective::PieceColor)
    perspective == WHITE && return square.val
    perspective == BLACK && return ((square.val - 1) ⊻ 7) + 1
    throw(ArgumentError("perspective must be WHITE or BLACK"))
end

"""
    feature_index(piece, square, perspective)

Return the 1-based index for a piece-square feature as viewed from `perspective`.
For the Black perspective, ranks and colors are flipped so both accumulators
share the same feature-transformer weights.
"""
function feature_index(piece::Piece, square::Square, perspective::PieceColor)
    piece == EMPTY && throw(ArgumentError("an empty square has no NNUE feature"))
    (perspective == WHITE || perspective == BLACK) ||
        throw(ArgumentError("perspective must be WHITE or BLACK"))

    color_offset = pcolor(piece) == perspective ? 0 : 6
    piece_bucket = color_offset + ptype(piece).val - 1
    return piece_bucket * 64 + perspective_square_index(square, perspective)
end

"""
    active_feature_indices(board, perspective)

Return the 32-or-fewer active piece-square features for one board perspective.
"""
function active_feature_indices(board::Board, perspective::PieceColor)
    indices = Int[]
    sizehint!(indices, 32)

    for square in occupiedsquares(board)
        push!(indices, feature_index(pieceon(board, square), square, perspective))
    end

    return indices
end

"""
    accumulator(model, board, perspective)

Build one perspective accumulator by summing embeddings for active features.
This full recomputation is the reference implementation; a later search
integration can update the same accumulator by subtracting and adding only the
features changed by a move.
"""
function accumulator(model::NNUEModel, board::Board, perspective::PieceColor)
    result = copy(model.feature_bias)

    for index in active_feature_indices(board, perspective)
        @views result .+= model.feature_weights[:, index]
    end

    return clipped_relu.(result)
end

"""
    nnue_evaluate(model, board)::Float32

Evaluate `board` and return a scalar in the engine's convention: positive
values favor White and negative values favor Black.
"""
function nnue_evaluate(model::NNUEModel, board::Board)::Float32
    white_accumulator = accumulator(model, board, WHITE)
    black_accumulator = accumulator(model, board, BLACK)

    network_input =
        sidetomove(board) == WHITE ?
        vcat(white_accumulator, black_accumulator) :
        vcat(black_accumulator, white_accumulator)

    side_to_move_score = only(model.output(model.hidden(network_input)))
    return sidetomove(board) == WHITE ? side_to_move_score : -side_to_move_score
end

(model::NNUEModel)(board::Board) = nnue_evaluate(model, board)

function validate_model_shapes(
    feature_weights,
    feature_bias,
    hidden_weights,
    hidden_bias,
    output_weights,
    output_bias,
)
    size(feature_weights, 2) == FEATURE_COUNT ||
        throw(ArgumentError("weight file has an incompatible feature count"))
    size(feature_weights, 1) == length(feature_bias) ||
        throw(ArgumentError("feature weight and bias dimensions do not match"))
    size(hidden_weights, 2) == 2 * length(feature_bias) ||
        throw(ArgumentError("hidden input does not match accumulator dimensions"))
    size(hidden_weights, 1) == length(hidden_bias) ||
        throw(ArgumentError("hidden weight and bias dimensions do not match"))
    size(output_weights) == (1, length(hidden_bias)) ||
        throw(ArgumentError("output weights must produce one scalar"))
    length(output_bias) == 1 ||
        throw(ArgumentError("output bias must contain one scalar"))
end

"""
    save_nnue(path, model)

Save model weights and architecture metadata in JLD2 format.
"""
function save_nnue(path::AbstractString, model::NNUEModel)
    JLD2.jldsave(
        path;
        format_version = FILE_FORMAT_VERSION,
        architecture = ARCHITECTURE_NAME,
        feature_count = FEATURE_COUNT,
        feature_weights = model.feature_weights,
        feature_bias = model.feature_bias,
        hidden_weights = model.hidden.weight,
        hidden_bias = model.hidden.bias,
        output_weights = model.output.weight,
        output_bias = model.output.bias,
    )
    return path
end

"""
    load_nnue(path)::NNUEModel

Load and validate an NNUE weight file created by [`save_nnue`](@ref).
"""
function load_nnue(path::AbstractString)
    data = JLD2.load(path)

    get(data, "format_version", nothing) == FILE_FORMAT_VERSION ||
        throw(ArgumentError("unsupported NNUE weight-file version"))
    get(data, "architecture", nothing) == ARCHITECTURE_NAME ||
        throw(ArgumentError("unsupported NNUE architecture"))
    get(data, "feature_count", nothing) == FEATURE_COUNT ||
        throw(ArgumentError("weight file has an incompatible feature count"))

    feature_weights = Matrix{Float32}(data["feature_weights"])
    feature_bias = Vector{Float32}(data["feature_bias"])
    hidden_weights = Matrix{Float32}(data["hidden_weights"])
    hidden_bias = Vector{Float32}(data["hidden_bias"])
    output_weights = Matrix{Float32}(data["output_weights"])
    output_bias = Vector{Float32}(data["output_bias"])

    validate_model_shapes(
        feature_weights,
        feature_bias,
        hidden_weights,
        hidden_bias,
        output_weights,
        output_bias,
    )

    hidden = Dense(hidden_weights, hidden_bias, clipped_relu)
    output = Dense(output_weights, output_bias)
    return NNUEModel(feature_weights, feature_bias, hidden, output)
end

end
