using Chess

const PROMOTION_ORDER_BONUS = 30_000
const CAPTURE_ORDER_BONUS = 20_000
const CHECK_ORDER_BONUS = 10_000
const EXCHANGE_ORDER_MULTIPLIER = 100

function promotion_order_value(piece_type::PieceType)
    if piece_type == QUEEN
        return 900
    elseif piece_type == ROOK
        return 500
    elseif piece_type == BISHOP
        return 300
    elseif piece_type == KNIGHT
        return 300
    end

    return 0
end

"""
    move_order_score(position, move)

Assign a tactical priority to a legal move. The score is only used to decide
which moves alpha-beta searches first; it is not a position evaluation.
"""
function move_order_score(position::Board, move::Move)
    score = 0

    if ispromotion(move)
        score += PROMOTION_ORDER_BONUS + promotion_order_value(promotion(move))
    end

    if moveiscapture(position, move)
        score += CAPTURE_ORDER_BONUS + EXCHANGE_ORDER_MULTIPLIER * see(position, move)
    end

    if moveischeck(position, move)
        score += CHECK_ORDER_BONUS
    end

    return score
end

"""
    ordered_moves(position, hash_move=MOVE_NULL)

Return legal moves with tactically promising moves first, allowing alpha-beta
to establish tighter bounds and prune more branches. A move stored in the
transposition table is searched before those tactical moves.
"""
function ordered_moves(position::Board, hash_move::Move = MOVE_NULL)
    legal_moves = collect(moves(position))
    sort!(legal_moves, by = move -> move_order_score(position, move), rev = true)
    if hash_move != MOVE_NULL
        index = findfirst(==(hash_move), legal_moves)
        if index !== nothing && index > 1
            best = legal_moves[index]
            deleteat!(legal_moves, index)
            pushfirst!(legal_moves, best)
        end
    end
    return legal_moves
end
