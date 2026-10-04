#This is code for a minimax engine
using Chess
include(joinpath(@__DIR__, "move_ordering.jl"))

const CHECKMATE_SCORE = 99999

# White-relative. A mate in fewer plies scores higher, and a loss is delayed when every defense loses.
function mate_value(position::Board, ply::Int)
    distance = CHECKMATE_SCORE - ply
    if sidetomove(position) == BLACK
        return distance
    else
        return -distance
    end
end

# Same side to move is two plies back, and a capture or pawn move ends the window.
# A copy inside this search is a cycle. A second older copy is the third occurrence.
function repeated(history::Vector{UInt64}, key::UInt64, rule50::Int, ply::Int)
    rule50 < 4 && return false
    limit = min(rule50, length(history))
    matches = 0
    distance = 2
    index = length(history) - 1
    while distance <= limit && index >= 1
        if history[index] == key
            matches += 1
            if distance < ply || matches == 2
                return true
            end
        end
        distance += 2
        index -= 2
    end
    false
end

function minimax(
    position::Board,
    depth::Int,
    maximizingPlayer::Bool,
    alpha = -Inf,
    beta = Inf,
    ply::Int = 0,
    history::Union{Nothing,Vector{UInt64}} = nothing,
)
    path = history === nothing ? UInt64[] : history
    if ischeckmate(position)
        return mate_value(position, ply)
    end
    if repeated(path, position.key, Int(position.r50), ply)
        return 0
    end
    if depth == 0 || isterminal(position)
        return evaluate(position)
    end

    push!(path, position.key)
    try
        if maximizingPlayer
            max_evaluation = -Inf
            for child in ordered_moves(position)
                evaluation = minimax(domove(position, child), depth - 1, false, alpha, beta, ply + 1, path)
                max_evaluation = max(max_evaluation, evaluation)
                alpha = max(alpha, max_evaluation)
                alpha >= beta && break
            end
            return max_evaluation
        else
            min_evaluation = Inf
            for child in ordered_moves(position)
                evaluation = minimax(domove(position, child), depth - 1, true, alpha, beta, ply + 1, path)
                min_evaluation = min(min_evaluation, evaluation)
                beta = min(beta, min_evaluation)
                alpha >= beta && break
            end
            return min_evaluation
        end
    finally
        pop!(path)
    end
end

function evaluate(position)
    if ischeckmate(position) && sidetomove(position) == BLACK
        return CHECKMATE_SCORE
    elseif ischeckmate(position) && sidetomove(position) == WHITE
        return -CHECKMATE_SCORE
    elseif isterminal(position)
        return 0
    end

    white_score = 0
    black_score = 0

    for sq in occupiedsquares(position)
        piece = pieceon(position, sq)
        piecetype = ptype(piece)
        value = get_piece_value(piecetype)

        if pcolor(piece) == WHITE
            white_score += value
        else
            black_score += value
        end
    end

    return white_score - black_score
end

function get_piece_value(pt::PieceType)
    if pt == PAWN
        return 1
    elseif pt == KNIGHT
        return 3
    elseif pt == BISHOP
        return 3
    elseif pt == ROOK
        return 5
    elseif pt == QUEEN
        return 9
    end
    return 0
end

function move(position::Board, depth::Int, history::Union{Nothing,Vector{UInt64}} = nothing)
    depth >= 1 || throw(ArgumentError("search depth must be at least 1"))
    legal_moves = ordered_moves(position)
    path = history === nothing ? UInt64[] : copy(history)
    push!(path, position.key)

    #if white
    if sidetomove(position) == WHITE
        best_eval = -Inf
        best_move = first(legal_moves)
        alpha = -Inf
        beta = Inf

        for move in legal_moves
            new_position = domove(position, move)
            evaluation = minimax(new_position, depth - 1, false, alpha, beta, 1, path)
            if evaluation > best_eval
                best_eval = evaluation
                best_move = lastmove(new_position)
            end
            alpha = max(alpha, best_eval)
        end

        return best_move
    else
        best_eval = Inf
        best_move = first(legal_moves)
        alpha = -Inf
        beta = Inf

        for move in legal_moves
            new_position = domove(position, move)
            evaluation = minimax(new_position, depth - 1, true, alpha, beta, 1, path)
            if evaluation < best_eval
                best_eval = evaluation
                best_move = lastmove(new_position)
            end
            beta = min(beta, best_eval)
        end

        return best_move

    end

end
