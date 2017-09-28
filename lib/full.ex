defmodule Full do

  use GenServer
  
  def create_network(n) do
    for x <- 1..n do
      name = droid_name(x)
      GenServer.start_link(Full, [x,n], name: name)
      name
    end
  end

  def init([x,n]) do
    {:ok, [0,0, n, x]  }
  end

  # def handle_cast({:add_random_neighbor, new_mate}, state ) do
  #   {:noreply,state ++ [new_mate]}
  # end

  def handle_cast({:message, _received}, [count,sent,n,x ] ) do
    length = round(:math.sqrt(n))
    i = rem(x,length) + 1
    j = round(x/length)+1
    case count do
      0 ->GenServer.cast(Master,{:received, [{i,j}]}) 
          Task.start_link(Full,:gossip,[x,self(),n,i,j])
      _ ->""
    end 
    {:noreply,[count+1 ,sent,n, x  ]}  
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

  def gossip(x,pid, n,i,j) do
    case GenServer.call(pid , :run) do
      true -> the_chosen_one(n)
              |> GenServer.cast({:message, :_sending})
              gossip(x,pid,n,i,j)
      false-> 
              GenServer.cast(Master,{:hibernated, [{i,j}]})              
    end
  end
    
  def droid_name(x) do
    a = x|> Integer.to_string |> String.pad_leading(7,"0")
    "Elixir.D"<>a
    |>String.to_atom
  end

  def the_chosen_one(n) do
    :rand.uniform(n)
    |> droid_name()
  end
end