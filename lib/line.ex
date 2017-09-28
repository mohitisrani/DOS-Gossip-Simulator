defmodule Line do
  
  use GenServer
  
    def create_network(n) do
      for x <- 1..n do
        name = droid_name(x)
        GenServer.start_link(Line, [x,n], name: name)
        name
      end
    end
  
    def init([x,n]) do
      mates = droid_mates(x,n)
      {:ok, [0,0, n, x | mates]  }
    end
  
    def handle_cast({:add_random_neighbor, new_mate}, state ) do
      {:noreply,state ++ [new_mate]}
    end
  
    def handle_cast({:message, _received}, [count,sent,n,x| mates ] ) do
      length = round(:math.sqrt(n))
      i = rem(x,length) + 1
      j = round(x/length)+1
      case count do
        0 ->GenServer.cast(Master,{:received, [{i,j}]}) 
            Task.start_link(Line,:gossip,[x,mates,self(),n,i,j])
        _ ->""
      end 
      {:noreply,[count+1 ,sent,n, x  | mates]}  
    end
    
    def handle_call(:run, _from, [count,sent,size | t]) do
      run =
        case rem(sent,100) do
          0 -> 
            sent != 10000
          _ ->
            count < 50
        end
      {:reply, run, [count,sent+1,size | t]}
    end
  
    def gossip(x,mates,pid, n,i,j) do
      case GenServer.call(pid , :run) do
        true -> the_chosen_one(mates)
                |> GenServer.cast({:message, :_sending})
                gossip(x,mates,pid,n,i,j)
        false-> 
                GenServer.cast(Master,{:hibernated, [{i,j}]})
                
      end
    end

  def droid_name(x) do
    a = x|> Integer.to_string |> String.pad_leading(7,"0")
    "Elixir.D"<>a
    |>String.to_atom
  end

  def droid_mates(self,n) do
    case self do
      1 -> [droid_name(n), droid_name(2)] 
      ^n -> [droid_name(n-1), droid_name(1)]
      _ -> [droid_name(self-1), droid_name(self+1)]
    end
  end

  def the_chosen_one(neighbors) do
    Enum.random(neighbors)
  end

end