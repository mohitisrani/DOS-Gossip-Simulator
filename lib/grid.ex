defmodule Grid do
  use GenServer

  def create_network(n ,imperfect \\ false, is_push_sum \\ 0) do

    droids = 
      for x <- 1..n, y<- 1..n do
        name = droid_name(x,y)
        GenServer.start_link(Grid, [x,y,n, is_push_sum], name: name)
        name
      end
    case imperfect do
      true -> randomify_mates( Enum.shuffle(droids) )
              "Imperfect Grid: #{inspect droids}"
      false -> "2D Grid: #{inspect droids}"
    end
  end

  def randomify_mates([a,b|droids]) do
    case droids do
      [] -> ""
      [_] -> ""
      _ -> GenServer.cast(a,{:add_random_neighbor, b})
           GenServer.cast(b,{:add_random_neighbor, a})
           randomify_mates(droids)
    end
  end

  # def init([x,y,n]) do
  #   mates = droid_mates(x,y,n)
  #   {:ok, [0,0,n*n, x, y | mates]  }
  # end

    # DECISION:  GOSSIP vs PUSH_SUM
  def init([x,y,n, is_push_sum]) do
    mates = droid_mates(x,y,n)
    case is_push_sum do
      0 -> {:ok, [0, 0, n*n, x, y | mates] } #[ rec_count, sent_count, n, self_number_id-x,y | neighbors ]
      1 -> {:ok, [0, 0, 0, 0, x, 1, n*n , x, y| mates] } #[ rec_count,streak,prev_s_w,to_terminate, s, w, n, self_number_id-x,y | neighbors ]
    end
  end

  # # NETWORK
  # def handle_cast({:add_random_neighbor, new_mate}, state ) do
  #   {:noreply,state ++ [new_mate]}
  # end

  # PUSHSUM - recieve gossip from others
  def handle_cast({:message_push_sum, {rec_s, rec_w} }, [count,streak,prev_s_w,term, s ,w, n, x, y | mates ] = state ) do   
    length = round(Float.ceil(:math.sqrt(n)))
    GenServer.cast(Master,{:received, [{x,y}]})
      case abs(((s+rec_s)/(w+rec_w))-prev_s_w) < :math.pow(10,-10) do
        false ->push_sum((s+rec_s)/2,(w+rec_w)/2,mates,self(),x,y) 
                {:noreply,[count+1, 0, (s+rec_s)/(w+rec_w), term, (s+rec_s)/2, (w+rec_w)/2, n, x, y  | mates]}
        true -> 
          case streak + 1 == 3 do
            true ->  GenServer.cast(Master,{:hibernated, [{x,y}]})
                      {:noreply,[count+1, streak+1, (s+rec_s)/(w+rec_w), 1, (s+rec_s), (w+rec_w), n, x, y  | mates]}
            false -> push_sum((s+rec_s)/2,(w+rec_w)/2,mates,self(),x,y) 
                      {:noreply,[count+1, streak+1, (s+rec_s)/(w+rec_w), 0, (s+rec_s)/2, (w+rec_w)/2, n, x, y  | mates]}
          end
        end
  end
  
    # PUSHSUM  - gossip
    def push_sum(s,w,mates,pid ,x,y) do
      the_chosen_one(mates)
      |> GenServer.cast({:message_push_sum,{ s,w}})
    end

  def handle_cast({:add_random_neighbor, new_mate}, state ) do
    {:noreply,state ++ [new_mate]}
  end



  def handle_cast({:message_gossip, _received}, [count,sent,size,x,y| mates ] ) do
    case count < 10 do
      true -> 
        GenServer.cast(Master,{:received, [{x,y}]}) 
        gossip(x,y,mates,self())
      false ->
        GenServer.cast(Master,{:hibernated, [{x,y}]})
    end
    {:noreply,[count+1 ,sent,size, x , y | mates]}  
  end
  
  # def handle_cast({:continue_gossip, [x,y,mates,pid]}, [count,sent,size | t]) do
  #   case count < 11 do
  #     true -> gossip(x,y,mates,pid)
  #     false -> GenServer.cast(Master,{:hibernated, [{x,y}]})
  #   end 
  #   {:noreply,[count ,sent+1,size | t]}
  # end

  def gossip(x,y,mates,pid) do
    the_chosen_one(mates)
    |> GenServer.cast({:message_gossip, :_sending})
    #GenServer.cast(pid,{:continue_gossip, [x,y,mates,pid]})   
  end
    
    
  def droid_name(x,y) do
    a = x|> Integer.to_string |> String.pad_leading(4,"0")
    b = y|> Integer.to_string |> String.pad_leading(4,"0")
    "Elixir.D"<>a<>""<>b
    |>String.to_atom
  end

  def the_chosen_one(neighbors) do
    Enum.random(neighbors)
  end

  def droid_mates(self_x,self_y,n) do   #where n is length of grid / sqrt of size of network
    [l,r] = 
        case self_x do
          1 -> [n, 2] 
          ^n -> [n-1, 1]
          _ -> [self_x-1, self_x+1]
        end    
    [t,b] = 
        case self_y do
          1 -> [n, 2] 
          ^n -> [n-1, 1]
          _ -> [self_y-1, self_y+1]
        end
    [droid_name(l,self_y),droid_name(r,self_y),droid_name(t,self_x),droid_name(b,self_x)]
  end


end