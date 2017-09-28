defmodule Grid do
  use GenServer

  def create_network(n ,imperfect \\ false) do

    droids = 
      for x <- 1..n, y<- 1..n do
        name = droid_name(x,y)
        GenServer.start_link(Grid, [x,y,n], name: name)
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
      _ -> Task.start_link(GenServer,:cast, [a,{:add_random_neighbor, b}])
           Task.start_link(GenServer,:cast, [b,{:add_random_neighbor, a}])
           randomify_mates(droids)
    end
  end

  def init([x,y,n]) do
    mates = droid_mates(x,y,n)
    {:ok, [0,0,n*n, x, y | mates]  }
  end

  def handle_cast({:add_random_neighbor, new_mate}, state ) do
    {:noreply,state ++ [new_mate]}
  end

  def handle_cast({:message, _received}, [count,sent,size,x,y| mates ] ) do
    case count do
      0 ->GenServer.cast(Master,{:received, [{x,y}]}) 
          Task.start_link(Grid,:gossip,[x,y,mates,self()])
      _ ->""
    end 
    {:noreply,[count+1 ,sent,size, x , y | mates]}  
  end
  
  def handle_call(:run, _from, [count,sent,size | t]) do
    run =
      case rem(sent,100) do
        0 -> 
          sent != 10000
        _ ->
          count < 10 
      end
    {:reply, run, [count,sent+1,size | t]}
  end

  def gossip(x,y,mates,pid) do
    case GenServer.call(pid , :run) do
      true -> the_chosen_one(mates)
              |> GenServer.cast({:message, :_sending})
              gossip(x,y,mates,pid)
      false-> 
              GenServer.cast(Master,{:hibernated, [{x,y}]})
              
    end
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
        case self_x do
          1 -> [n, 2] 
          ^n -> [n-1, 1]
          _ -> [self_y-1, self_y+1]
        end
    [droid_name(l,self_y),droid_name(r,self_y),droid_name(t,self_x),droid_name(b,self_x)]
  end


end