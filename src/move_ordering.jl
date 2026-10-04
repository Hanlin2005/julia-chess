using Chess

const PROMOTION_ORDER_BONUS = 30_000
const CAPTURE_ORDER_BONUS = 20_000
# Pawn, knight, bishop, rook, queen, king. The king is dearest so it captures last.
const ORDER_PIECE_VALUE = (100, 320, 330, 500, 900, 10_000)

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
function exchange_order_value(position::Board, move::Move)
    attacker = ORDER_PIECE_VALUE[ptype(pieceon(position, from(move))).val]
    if moveisep(position, move)
        victim = ORDER_PIECE_VALUE[1]
    else
        captured = pieceon(position, to(move))
        victim = captured == EMPTY ? 0 : ORDER_PIECE_VALUE[ptype(captured).val]
    end
    return victim - attacker
end

function move_order_score(position::Board, move::Move)
    score = 0

    if ispromotion(move)
        score += PROMOTION_ORDER_BONUS + promotion_order_value(promotion(move))
    end

    if moveiscapture(position, move)
        score += CAPTURE_ORDER_BONUS + exchange_order_value(position, move)
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

"""
    tactical_moves(position, hash_move=MOVE_NULL)

Legal captures and promotions, with the same ordering as `ordered_moves`.
Quiescence search uses this list once the main depth is exhausted.
"""
function tactical_moves(position::Board, hash_move::Move = MOVE_NULL)
    legal_moves = [move for move in moves(position) if moveiscapture(position, move) || ispromotion(move)]
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
