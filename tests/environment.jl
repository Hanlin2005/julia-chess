#This environment is for comparing the performance of chess engines.
using Chess
include("../src/engine.jl")

mutable struct Engine
    func::Function
    eloscore::Int
end

function create_engine(func::Function, initial_elo::Int = 1000)
    return Engine(func, initial_elo)
end

#ELO update
function elo_update(playerA::Engine, playerB::Engine, result::Int, K::Int)
    #calculate the expected scores
    expectedscoreA = 1 / (1 + 10^((playerB.eloscore - playerA.eloscore)/400))
    expectedscoreB =  1 / (1 + 10^((playerA.eloscore - playerB.eloscore)/400))

    if result == 1
        playerA.eloscore = playerA.eloscore + K*(1-expectedscoreA)
        playerB.eloscore = playerB.eloscore + K*(0-expectedscoreB)
    elseif result == 0
        playerA.eloscore = playerA.eloscore + K*(0.5-expectedscoreA)
        playerB.eloscore = playerB.eloscore + K*(0.5-expectedscoreB)
    else
        playerA.eloscore = playerA.eloscore + K*(0-expectedscoreA)
        playerB.eloscore = playerB.eloscore + K*(1-expectedscoreB)
    end

end

#Code to simulate one game, here player A is white
function run_game(playerA::Engine, playerB::Engine)
    playerAturn = true
    board = startboard()

    while !isterminal(board)
        if playerAturn
            move = playerA.func(board)
            playerAturn = false
        else
            move = playerB.func(board)
            playerAturn = true
        end
        
        domove!(board, move)

    end

    if ischeckmate(board ) && sidetomove(board) == "BLACK"
        result = 1
    elseif ischeckmate(board ) && sidetomove(board) == "WHITE"
        result = -1
    else
        result = 0
    end

    return result

end

#Function to simulate games
function simulate_games(rounds::Int, players::Vector{Engine}, K_factor::Int = 10)
    println("Starting Simulation")
    for round in 1:rounds
    println("Simulating Round ", round, " of ", rounds)
        for i in 1:length(players)

            playerA = players[i]

            for j in i+1:length(players)

                playerB = players[j]
                #PlayerA as white
                result = run_game(playerA, playerB)
                elo_update(playerA, playerB, result, K_factor)
                #PlayerB as white
                result = run_game(playerB, playerA)
                elo_update(playerB, playerA, result, K_factor)

            end
        end
    end
end

#Functions for specific engines
function create_mcts(simulations::Int, initial_elo::Int = 1000, max_children::Int = 100, exploration_term::Float64 = 2.0)

    function mcts_func(board::Board)
        return mcts(board, simulations, max_children = max_children, exploration_term = exploration_term)
    end

    return Engine(mcts_func, initial_elo)
end

players = Vector{Engine}()
for i in 1:5
    push!(players, create_mcts(100))
end

simulate_games(100,players)

for player in players
    println("players and scores: ")
    print(player.eloscore, " ")
end