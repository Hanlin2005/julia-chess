using Chess

# A stored score near mate is adjusted by ply on the way in and out.
const MATE_SCORE_FLOOR = 90_000

@enum Bound::UInt8 EXACT LOWER UPPER

struct TTEntry
    key::UInt64
    depth::Int
    score::Float64
    bound::Bound
    best_move::Move
    generation::UInt8
    occupied::Bool
end

mutable struct TranspositionTable
    entries::Vector{TTEntry}
    generation::UInt8
end

struct TTProbe
    hit::Bool
    cutoff::Bool
    score::Float64
    alpha::Float64
    beta::Float64
    best_move::Move
end

const EMPTY_ENTRY = TTEntry(0, -1, 0.0, EXACT, MOVE_NULL, 0, false)

function TranspositionTable(size::Int = 1 << 18)
    slots = nextpow(2, max(size, 1))
    return TranspositionTable(fill(EMPTY_ENTRY, slots), UInt8(1))
end

function new_generation!(table::TranspositionTable)
    if table.generation == typemax(UInt8)
        table.generation = UInt8(1)
    else
        table.generation += UInt8(1)
    end
    return table
end

function pack_score(score::Real, ply::Int)
    value = Float64(score)
    if value >= MATE_SCORE_FLOOR
        return value + ply
    elseif value <= -MATE_SCORE_FLOOR
        return value - ply
    end
    return value
end

function unpack_score(score::Float64, ply::Int)
    if score >= MATE_SCORE_FLOOR
        return score - ply
    elseif score <= -MATE_SCORE_FLOOR
        return score + ply
    end
    return score
end

function store!(table::TranspositionTable, key::UInt64, depth::Int, score::Real, bound::Bound, best_move::Move)
    index = Int(key & (length(table.entries) - 1)) + 1
    current = table.entries[index]
    if current.occupied
        if current.key == key
            depth < current.depth && return
        elseif current.generation == table.generation && depth < current.depth
            return
        end
    end
    table.entries[index] = TTEntry(key, depth, Float64(score), bound, best_move, table.generation, true)
    return
end

function probe(table::TranspositionTable, key::UInt64, depth::Int, alpha::Real, beta::Real, ply::Int)
    index = Int(key & (length(table.entries) - 1)) + 1
    entry = table.entries[index]
    alpha = Float64(alpha)
    beta = Float64(beta)
    if !entry.occupied || entry.key != key
        return TTProbe(false, false, 0.0, alpha, beta, MOVE_NULL)
    end
    if entry.depth < depth
        return TTProbe(true, false, 0.0, alpha, beta, entry.best_move)
    end

    score = unpack_score(entry.score, ply)
    if entry.bound == EXACT ||
       (entry.bound == LOWER && score >= beta) ||
       (entry.bound == UPPER && score <= alpha)
        return TTProbe(true, true, score, alpha, beta, entry.best_move)
    end
    if entry.bound == LOWER && score > alpha
        alpha = score
    elseif entry.bound == UPPER && score < beta
        beta = score
    end
    return TTProbe(true, false, score, alpha, beta, entry.best_move)
end
