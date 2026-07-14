using Test
using Chess
using Random

include(joinpath(@__DIR__, "..", "src", "NNUE.jl"))
using .NNUE

@testset "NNUE features" begin
    @test FEATURE_COUNT == 12 * 64

    white_pawn_from_white = feature_index(PIECE_WP, SQ_A2, WHITE)
    black_pawn_from_black = feature_index(PIECE_BP, SQ_A7, BLACK)
    @test white_pawn_from_white == black_pawn_from_black

    board = startboard()
    white_features = active_feature_indices(board, WHITE)
    black_features = active_feature_indices(board, BLACK)
    @test length(white_features) == 32
    @test length(black_features) == 32
    @test all(index -> 1 <= index <= FEATURE_COUNT, white_features)
    @test all(index -> 1 <= index <= FEATURE_COUNT, black_features)
    @test_throws ArgumentError feature_index(EMPTY, SQ_A1, WHITE)
end

@testset "NNUE inference" begin
    first_model = NNUEModel(
        accumulator_dim = 16,
        hidden_dim = 8,
        rng = MersenneTwister(42),
    )
    second_model = NNUEModel(
        accumulator_dim = 16,
        hidden_dim = 8,
        rng = MersenneTwister(42),
    )
    board = startboard()

    white_accumulator = accumulator(first_model, board, WHITE)
    @test length(white_accumulator) == 16
    @test all(value -> 0f0 <= value <= 1f0, white_accumulator)

    score = nnue_evaluate(first_model, board)
    @test score isa Float32
    @test isfinite(score)
    @test first_model(board) == score
    @test nnue_evaluate(second_model, board) == score

    flipped_score = nnue_evaluate(first_model, flip(board))
    @test flipped_score ≈ -score
end

@testset "NNUE persistence" begin
    model = NNUEModel(
        accumulator_dim = 12,
        hidden_dim = 6,
        rng = MersenneTwister(7),
    )
    board = startboard()

    mktempdir() do directory
        path = joinpath(directory, "test-weights.jld2")
        @test save_nnue(path, model) == path

        loaded_model = load_nnue(path)
        @test loaded_model.feature_weights == model.feature_weights
        @test loaded_model.feature_bias == model.feature_bias
        @test loaded_model.hidden.weight == model.hidden.weight
        @test loaded_model.hidden.bias == model.hidden.bias
        @test loaded_model.output.weight == model.output.weight
        @test loaded_model.output.bias == model.output.bias
        @test nnue_evaluate(loaded_model, board) == nnue_evaluate(model, board)
    end
end
