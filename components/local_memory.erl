-module(local_memory).
-export([listen/6]).


% ff_logic, clk driven
listen(PE, IndexMemory, InputMemory, WeightMemory, VectorMulMemory, SigmoidMemory) ->
    receive
        % Erase LocalMemory cell
        {erase} -> receive {clk} -> listen(PE, [], [], [], [], []) end;

        % Append a new index value
        {write, index, Index} -> receive {clk} -> listen(PE, IndexMemory ++ [Index], InputMemory, WeightMemory, VectorMulMemory, SigmoidMemory) end;

        % Append new inputs vector
        {write, inputs, List} -> receive {clk} -> listen(PE, IndexMemory, InputMemory ++ [List], WeightMemory, VectorMulMemory, SigmoidMemory) end;

        % Append new weights vector
        {write, weights, List} -> receive {clk} -> listen(PE, IndexMemory, InputMemory, WeightMemory ++ [List], VectorMulMemory, SigmoidMemory) end;

        % Append new vector_mul value
        {write, vector_mul, Value} -> receive {clk} -> listen(PE, IndexMemory, InputMemory, WeightMemory, VectorMulMemory ++ [Value], SigmoidMemory) end;

        % Append new activation_func value
        {write, activation, Value} -> receive {clk} -> listen(PE, IndexMemory, InputMemory, WeightMemory, VectorMulMemory, SigmoidMemory ++ [Value]) end;

        % Read all memory banks and send the to IO
        {read, Bus} -> Bus ! {output_results, [{1, IndexMemory}, {2, InputMemory}, {3, WeightMemory}, {4, VectorMulMemory}, {5, SigmoidMemory}]};

        % Send inputs and weights vectors to mul PE. Pop weights
        {calc, inputs_and_weights} ->
            receive
                {clk} ->
                    case WeightMemory of
                        [] -> listen(PE, IndexMemory, InputMemory, WeightMemory, VectorMulMemory, SigmoidMemory);
                        _ ->
                            [InputVector] = InputMemory,
                            [FirstWeight | WeightTail] = WeightMemory,
                            PE ! {self(), vector_mul, InputVector, FirstWeight},

                            receive
                                {write, vector_mul, Value} -> listen(PE, IndexMemory, InputMemory, WeightTail, VectorMulMemory ++ [Value], SigmoidMemory)
                            end
                    end
            end;

        % Send vector_mul to PE. Pop vector_mul
        {calc, vector_mul} ->
            receive
                {clk} ->
                    case VectorMulMemory of
                        [] -> listen(PE, IndexMemory, InputMemory, WeightMemory, VectorMulMemory, SigmoidMemory);
                        _ ->
                            [FirstVectorMul | VectorMulTail] = VectorMulMemory,
                            PE ! {self(), activation_func, FirstVectorMul},

                            receive
                                {write, activation, Value} -> listen(PE, IndexMemory, InputMemory, WeightMemory, VectorMulTail, SigmoidMemory ++ [Value])
                            end
                    end
            end;

        % Send results to Bus. Pop sigmoid and index
        {get_result, Bus} ->
            receive
                {clk} ->
                    case {IndexMemory, SigmoidMemory} of
                        {[], []} -> listen(PE, IndexMemory, InputMemory, WeightMemory, VectorMulMemory, SigmoidMemory);
                        _ ->
                            [FirstIndex | IndexTail] = IndexMemory,
                            [FirstSigmoid | SigmoidTail] = SigmoidMemory,
                            Bus ! {result, FirstIndex, FirstSigmoid},
                            listen(PE, IndexTail, InputMemory, WeightMemory, VectorMulMemory, SigmoidTail)
                    end
            end;

        _ -> listen(PE, IndexMemory, InputMemory, WeightMemory, VectorMulMemory, SigmoidMemory)
    end,

    listen(PE, IndexMemory, InputMemory, WeightMemory, VectorMulMemory, SigmoidMemory).