#This is code for a minimax engine
using Chess
include(joinpath(@__DIR__, "move_ordering.jl"))
include(joinpath(@__DIR__, "transposition.jl"))

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
    table::Union{Nothing,TranspositionTable} = nothing,
)
    path = history === nothing ? UInt64[] : history
    if ischeckmate(position)
        return mate_value(position, ply)
    end
    if repeated(path, position.key, Int(position.r50), ply)
        return 0
    end

    original_alpha = alpha
    original_beta = beta
    hash_move = MOVE_NULL
    if table !== nothing
        probed = probe(table, position.key, depth, alpha, beta, ply)
        hash_move = probed.best_move
        if probed.cutoff
            return probed.score
        end
        alpha = probed.alpha
        beta = probed.beta
    end

    if depth == 0 || isterminal(position)
        score = evaluate(position)
        if table !== nothing
            store!(table, position.key, depth, pack_score(score, ply), EXACT, MOVE_NULL)
        end
        return score
    end

    push!(path, position.key)
    try
        if maximizingPlayer
            max_evaluation = -Inf
            best_move = MOVE_NULL
            for child in ordered_moves(position, hash_move)
                evaluation = minimax(domove(position, child), depth - 1, false, alpha, beta, ply + 1, path, table)
                if evaluation > max_evaluation
                    max_evaluation = evaluation
                    best_move = child
                end
                alpha = max(alpha, max_evaluation)
                alpha >= beta && break
            end
            if table !== nothing && best_move != MOVE_NULL
                bound = if alpha >= beta
                    LOWER
                elseif max_evaluation <= original_alpha
                    UPPER
                else
                    EXACT
                end
                store!(table, position.key, depth, pack_score(max_evaluation, ply), bound, best_move)
            end
            return max_evaluation
        else
            min_evaluation = Inf
            best_move = MOVE_NULL
            for child in ordered_moves(position, hash_move)
                evaluation = minimax(domove(position, child), depth - 1, true, alpha, beta, ply + 1, path, table)
                if evaluation < min_evaluation
                    min_evaluation = evaluation
                    best_move = child
                end
                beta = min(beta, min_evaluation)
                alpha >= beta && break
            end
            if table !== nothing && best_move != MOVE_NULL
                bound = if alpha >= beta
                    UPPER
                elseif min_evaluation >= original_beta
                    LOWER
                else
                    EXACT
                end
                store!(table, position.key, depth, pack_score(min_evaluation, ply), bound, best_move)
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

function move(
    position::Board,
    depth::Int,
    history::Union{Nothing,Vector{UInt64}} = nothing,
    table::Union{Nothing,TranspositionTable} = nothing,
)
    depth >= 1 || throw(ArgumentError("search depth must be at least 1"))
    if table === nothing
        table = TranspositionTable()
    end

    probed = probe(table, position.key, depth, -Inf, Inf, 0)
    if probed.cutoff && probed.best_move != MOVE_NULL
        return probed.best_move
    end

    legal_moves = ordered_moves(position, probed.best_move)
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
            evaluation = minimax(new_position, depth - 1, false, alpha, beta, 1, path, table)
            if evaluation > best_eval
                best_eval = evaluation
                best_move = lastmove(new_position)
            end
            alpha = max(alpha, best_eval)
        end

        store!(table, position.key, depth, pack_score(best_eval, 0), EXACT, best_move)
        return best_move
    else
        best_eval = Inf
        best_move = first(legal_moves)
        alpha = -Inf
        beta = Inf

        for move in legal_moves
            new_position = domove(position, move)
            evaluation = minimax(new_position, depth - 1, true, alpha, beta, 1, path, table)
            if evaluation < best_eval
                best_eval = evaluation
                best_move = lastmove(new_position)
            end
            beta = min(beta, best_eval)
        end

        store!(table, position.key, depth, pack_score(best_eval, 0), EXACT, best_move)
        return best_move

    end

end
