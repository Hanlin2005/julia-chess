using Chess
using Random

#Structure for Node of Monte Carlo Tree Search
mutable struct Node 
    position::Board
    value::Int
    visits::Int
    children::Vector{Node}
    parent::Union{Node, Nothing}
end

#Function to create a new node 
function create_node(position::Board, parent = nothing)
    return Node(position, 0, 0, Node[], parent)
end

#Function to add children, when node is a leaf node and visits is not zero
function add_children(currentNode::Node, max_children)

    board = currentNode.position
    legalmoves = collect(moves(board))
    shuffle!(legalmoves)

    for mv in Iterators.take(legalmoves, max_children)
        new_board = domove(board, mv)
        childNode = create_node(new_board, currentNode)
        push!(currentNode.children, childNode)
    end

end

#Function for rollout
function rollout(currentNode::Node)

    #Simulate random games until end
    nodeColor = sidetomove(currentNode.position)
    position = currentNode.position
    movecount = 0

    while !isterminal(position)
        legalmoves = moves(position)
        position = domove(position, rand(legalmoves))
        movecount += 5
    end
    
    if ischeckmate(position) && sidetomove(position) == nodeColor && movecount == 0
        back_propagate(currentNode, 1000)
    elseif ischeckmate(position) && sidetomove(position) == nodeColor
        back_propagate(currentNode, 100 - movecount)
    elseif ischeckmate(position) && sidetomove(position) != nodeColor
        back_propagate(currentNode, -100 - movecount)
    else
        back_propagate(currentNode, 0)
    end

end

#function to evaluate UCB1 value
function evaluate_node(currentNode::Node, exploration_term = 2.0)
    if currentNode.visits==0
        return Inf
    end

    parent_visits = currentNode.parent.visits
    visits = currentNode.visits
    value = currentNode.value

    return value/visits + exploration_term * sqrt(log(parent_visits)/visits)
end

#function to back propagate
function back_propagate(currentNode::Node, result::Int)

    current = currentNode

    while current !== nothing
        current.value += result
        current.visits += 1
        result = -result
        current = current.parent
    end
end

#function to select best child
function select_child(currentNode::Node, exploration_term::Float64)

    if all(child -> child.visits == 0, currentNode.children)
        return currentNode.children[1]
    end

    return currentNode.children[argmax(evaluate_node(child, exploration_term) for child in currentNode.children)]
end

#MCTS algorithm
function mcts(initial_position::Board, simulations::Int; max_children::Int = 10, exploration_term = 2.0)

    #make sure root node has children
    root = create_node(initial_position)
    add_children(root, max_children)
    #if isempty(root.children[1].children)
       # print(lastmove(root.children[1].position))
       # print(isterminal(root.children[1].position))
       # print(sidetomove(root.children[1].position))
    #end

    #start iterations
    for _ in 1:simulations
        current = root

        while !isempty(current.children)
            current = select_child(current, exploration_term)
        end

        if isterminal(current.position)
            rollout(current)
            continue
        else
            if current.visits == 0
                rollout(current)
            else
                add_children(current, max_children)
                current = select_child(current, exploration_term)
                rollout(current)
            end

        end

    end

    #print(collect(evaluate_node(child, exploration_term) for child in root.children))
    return lastmove(select_child(root, exploration_term).position)
end