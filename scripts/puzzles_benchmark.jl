# Puzzles benchmark for the minimax engine.
#
# The final rating is the highest rating at which every selected puzzle of
# that rating or lower was solved.
#
# Usage:
#     julia --project=. scripts/puzzles_benchmark.jl [depth]

using Chess
using Printf

include(joinpath(@__DIR__, "..", "src", "minimax.jl"))
include(joinpath(@__DIR__, "..", "data", "benchmark_puzzles.jl"))

if isempty(ARGS)
    search_depth = 3
elseif length(ARGS) == 1
    search_depth = tryparse(Int, ARGS[1])
    if search_depth === nothing || search_depth < 1
        error("depth must be an integer of at least 1")
    end
else
    error("Usage: julia --project=. scripts/puzzles_benchmark.jl [depth]")
end

const SEARCH_DEPTH = search_depth

function main()
    println("Puzzles benchmark")
    results = Tuple{Int, Bool}[]

    for (id, rating, fen, expected, mate_in_one) in BENCHMARK_PUZZLES
        board = fromfen(fen)
        played = move(board, SEARCH_DEPTH)
        if mate_in_one
            ok = ischeckmate(domove(board, played))
        else
            ok = tostring(played) == expected
        end
        println("$id  $rating  $(ok ? "solved" : "missed")  $(tostring(played))")
        push!(results, (rating, ok))
    end

    println()
    @printf("%-12s  %8s  %10s  %8s\n", "Rating band", "Solved", "Succeeded", "Failed")
    bands = sort(unique(rating ÷ 100 * 100 for (rating, _) in results))
    for band in bands
        group = [ok for (rating, ok) in results if rating ÷ 100 * 100 == band]
        solved = count(group)
        total = length(group)
        failed = total - solved
        @printf(
            "%4d-%-7d  %3d/%-4d  %9.1f%%  %7.1f%%\n",
            band,
            band + 99,
            solved,
            total,
            100 * solved / total,
            100 * failed / total,
        )
    end

    solved_ratings = [rating for (rating, ok) in results if ok]
    missed_ratings = [rating for (rating, ok) in results if !ok]
    println()
    if isempty(missed_ratings)
        println("Final rating: $(maximum(solved_ratings))")
    else
        cutoff = minimum(missed_ratings)
        below = [rating for rating in solved_ratings if rating < cutoff]
        if isempty(below)
            println("Final rating: none")
        else
            println("Final rating: $(maximum(below))")
        end
    end
    println("Highest solved: $(isempty(solved_ratings) ? "none" : maximum(solved_ratings))")
    println("Lowest missed: $(isempty(missed_ratings) ? "none" : minimum(missed_ratings))")
end

main()
