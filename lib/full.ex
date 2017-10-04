defmodule Full do

  use GenServer
  
  def create_network(n, is_push_sum \\ 0) do
    for x <- 1..n do
      name = droid_name(x)
      GenServer.start_link(Full, [x,n,is_push_sum], name: name)
      name
    end
  end

  # DECISION:  GOSSIP vs PUSH_SUM
  def init([x,n, is_push_sum]) do
    case is_push_sum do
      0 -> {:ok, [0,0, n, x ] } #[ rec_count, sent_count, n, self_number_id | neighbors ]
      1 -> {:ok, [0, 0, 0, 0, x, 1, n, x] } #[ rec_count,streak,prev_s_w,to_terminate, s, w, n, self_number_id | neighbors ]
    end
  end

  # PUSHSUM - recieve gossip from others
  def handle_cast({:message_push_sum, {rec_s, rec_w} }, [count,streak,prev_s_w,term, s ,w, n, x] = state ) do   
    length = round(Float.ceil(:math.sqrt(n)))
    i = rem(x-1,length) + 1
    j = round(Float.floor(((x-1)/length))) + 1
    GenServer.cast(Master,{:received, [{i,j}]})
      case abs(((s+rec_s)/(w+rec_w))-prev_s_w) < :math.pow(10,-10) do
        false ->push_sum((s+rec_s)/2,(w+rec_w)/2,self(),n,i,j) 
                {:noreply,[count+1, 0, (s+rec_s)/(w+rec_w), term, (s+rec_s)/2, (w+rec_w)/2, n, x ]}
        true -> 
          case streak + 1 == 3 do
            true ->  GenServer.cast(Master,{:hibernated, [{i,j}]})
                      {:noreply,[count+1, streak+1, (s+rec_s)/(w+rec_w), 1, (s+rec_s), (w+rec_w), n, x ]}
            false -> push_sum((s+rec_s)/2,(w+rec_w)/2,self(),n,i,j) 
                      {:noreply,[count+1, streak+1, (s+rec_s)/(w+rec_w), 0, (s+rec_s)/2, (w+rec_w)/2, n, x ]}
          end
        end
  end
    
  # PUSHSUM  - gossip
  def push_sum(s,w,pid,n ,i,j) do
    the_chosen_one(n)
    |> GenServer.cast({:message_push_sum,{s,w}})
  end

  def handle_cast({:message_gossip, _received}, [count,sent,n,x ] ) do
    length = round(Float.ceil(:math.sqrt(n)))
    i = rem(x-1,length) + 1
    j = round(Float.floor(((x-1)/length))) + 1
    case count < 11 do
      true ->
        GenServer.cast(Master,{:received, [{i,j}]}) 
        gossip(x,self(),n,i,j)
      false ->
        GenServer.cast(Master,{:hibernated, [{i,j}]})
    end
    {:noreply,[count+1 ,sent,n, x  ]}
  end

  def gossip(x,pid, n,i,j) do
    the_chosen_one(n)
    |> GenServer.cast({:message_gossip, :_sending})
    #GenServer.cast(pid,{:continue_gossip,[x,pid,n,i,j]})
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