defmodule Line do
  
  use GenServer
  # NETWORK
  def create_network(n, is_push_sum \\ 0) do
    for x <- 1..n do
      name = droid_name(x)
      GenServer.start_link(Line, [x,n, is_push_sum], name: name)
      name
    end
  end

  # DECISION:  GOSSIP vs PUSH_SUM
  def init([x,n, is_push_sum]) do
    mates = droid_mates(x,n)
    case is_push_sum do
      0 -> {:ok, [0,0, n, x | mates] } #[ rec_count, sent_count, n, self_number_id | neighbors ]
      1 -> {:ok, [0, 0, 0, 0, x, 1, n, x| mates] } #[ rec_count,streak,prev_s_w,to_terminate, s, w, n, self_number_id | neighbors ]
    end
  end

  # # NETWORK
  # def handle_cast({:add_random_neighbor, new_mate}, state ) do
  #   {:noreply,state ++ [new_mate]}
  # end

  # PUSHSUM - recieve gossip from others
  def handle_cast({:message_push_sum, {rec_s, rec_w} }, [count,streak,prev_s_w,term, s ,w, n, x | mates ] = state ) do   
    length = round(Float.ceil(:math.sqrt(n)))
    i = rem(x-1,length) + 1
    j = round(Float.floor(((x-1)/length))) + 1
    GenServer.cast(Master,{:received, [{i,j}]})
      case abs(((s+rec_s)/(w+rec_w))-prev_s_w) < :math.pow(10,-10) do
        false ->push_sum((s+rec_s)/2,(w+rec_w)/2,mates,self(),i,j) 
                {:noreply,[count+1, 0, (s+rec_s)/(w+rec_w), term, (s+rec_s)/2, (w+rec_w)/2, n, x  | mates]}
        true -> 
          case streak + 1 == 3 do
            true ->  GenServer.cast(Master,{:hibernated, [{i,j}]})
                      {:noreply,[count+1, streak+1, (s+rec_s)/(w+rec_w), 1, (s+rec_s), (w+rec_w), n, x  | mates]}
            false -> push_sum((s+rec_s)/2,(w+rec_w)/2,mates,self(),i,j) 
                      {:noreply,[count+1, streak+1, (s+rec_s)/(w+rec_w), 0, (s+rec_s)/2, (w+rec_w)/2, n, x  | mates]}
          end
        end
  end
  
    # PUSHSUM  - gossip
    def push_sum(s,w,mates,pid ,i,j) do
      the_chosen_one(mates)
      |> GenServer.cast({:message_push_sum,{ s,w}})
    end

  # GOSSIP - recieve gossip from others
  def handle_cast({:message_gossip, _received}, [count,sent,n,x| mates ] ) do   
    length = round(Float.ceil(:math.sqrt(n)))
    i = rem(x-1,length) + 1
    j = round(Float.floor(((x-1)/length))) + 1
    case count < 200 do
    true ->  GenServer.cast(Master,{:received, [{i,j}]}) 
             gossip(x,mates,self(),n,i,j)
    false -> GenServer.cast(Master,{:hibernated, [{i,j}]})
    end 
    {:noreply,[count+1 ,sent,n, x  | mates]}  
  end

  # # GOSSIP  - check and continue gossip
  # def handle_cast({:continue_gossip, [x,mates,pid,n,i,j]}, [count,sent,size | t]) do
  #   case count < 20 do
  #     true -> gossip(x,mates,pid,n,i,j)
  #     false -> GenServer.cast(Master,{:hibernated, [{i,j}]})
  #   end
  #   {:noreply,[count ,sent+1,size | t]}
  # end

  # GOSSIP  - gossip
  def gossip(x,mates,pid, n,i,j) do
    the_chosen_one(mates)
    |> GenServer.cast({:message_gossip, :_sending})
    #GenServer.cast(pid,{:continue_gossip, [x,mates,pid,n,i,j]})
  end

  # NETWORK
  def droid_name(x) do
    a = x|> Integer.to_string |> String.pad_leading(7,"0")
    "Elixir.D"<>a
    |>String.to_atom
  end

  # NETWORK
  def droid_mates(self,n) do
    case self do
      1 -> [droid_name(n), droid_name(2)] 
      ^n -> [droid_name(n-1), droid_name(1)]
      _ -> [droid_name(self-1), droid_name(self+1)]
    end
  end

  # NETWORK
  def the_chosen_one(neighbors) do
    Enum.random(neighbors)
  end

end