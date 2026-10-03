A personal project of creating a chess engine in Julia.

As of August 7th, 2025, the bot has been implemented on lichess.org.
The bot account is: https://lichess.org/@/JuliaEngine

As of August 27th, I have added the minimax algorithm and the testing environment

I am continuing to improve its performance!

To run the tests, run `julia --project=. test/runtests.jl`. To search at another depth, add it at the end, for example `julia --project=. test/runtests.jl 4`. The default depth is 3.

To run the puzzles benchmark, run `julia --project=. scripts/puzzles_benchmark.jl`. To search at another depth, add it the same way, for example `julia --project=. scripts/puzzles_benchmark.jl 4`. The final rating is the highest rating at which every selected puzzle of that rating or lower was solved.