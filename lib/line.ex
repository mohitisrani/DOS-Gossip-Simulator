defmodule Line do
  use GenServer


  # DECISION : GOSSIP vs PUSH_SUM
  def init([x,n, is_push_sum]) do
    mates = droid_mates(x,n)
    case is_push_sum do
      0 -> {:ok, [Active,0,0, n, x | mates] } #[ status, rec_count, sent_count, n, self_number_id | neighbors ]
      1 -> {:ok, [Active,0, 0, 0, 0, x, 1, n, x| mates] } #[status, rec_count,streak,prev_s_w,to_terminate, s, w, n, self_number_id | neighbors ]
    end
  end

  # PUSHSUM #######################################################################################

  # PUSHSUM - RECIEVE Main
  def handle_cast({:message_push_sum, {rec_s, rec_w} }, [status,count,streak,prev_s_w,term, s ,w, n, x | mates ] = state ) do   
    length = round(Float.ceil(:math.sqrt(n)))
    i = rem(x-1,length) + 1
    j = round(Float.floor(((x-1)/length))) + 1
    GenServer.cast(Master,{:received, [{i,j}]})
      case abs(((s+rec_s)/(w+rec_w))-prev_s_w) < :math.pow(10,-10) do
        false ->push_sum((s+rec_s)/2,(w+rec_w)/2,mates,self(),i,j) 
                {:noreply,[status,count+1, 0, (s+rec_s)/(w+rec_w), term, (s+rec_s)/2, (w+rec_w)/2, n, x  | mates]}
        true -> 
          case streak + 1 == 3 do
            true ->  GenServer.cast(Master,{:hibernated, [{i,j}]})
                      {:noreply,[status,count+1, streak+1, (s+rec_s)/(w+rec_w), 1, (s+rec_s), (w+rec_w), n, x  | mates]}
            false -> push_sum((s+rec_s)/2, (w+rec_w)/2, mates, self(), i, j)
                      {:noreply,[status,count+1, streak+1, (s+rec_s)/(w+rec_w), 0, (s+rec_s)/2, (w+rec_w)/2, n, x  | mates]}
          end
      end
  end
  
  # PUSHSUM  - SEND MAIN
  def push_sum(s,w,mates,pid ,i,j) do
    the_one = the_chosen_one(mates)
    case GenServer.call(the_one,:is_active) do
      Active -> GenServer.cast(the_one,{:message_push_sum,{ s,w}})
      ina_xy ->  GenServer.cast(Master,{:droid_inactive, ina_xy})
                new_mate = GenServer.call(Master,:handle_node_failure)
                GenServer.cast(self(),{:remove_mate,the_one})
                GenServer.cast(self(),{:add_new_mate,new_mate})
                GenServer.cast(self(),{:retry_push_sum,{s,w,pid,i,j}})
    end
  end

    # PUSHSUM - HANDLE FAILURE SEND retry - in case the Node is inactive
    def handle_cast({:retry_push_sum, {rec_s, rec_w,pid,i,j} }, [status,count,streak,prev_s_w,term, s ,w, n, x | mates ] = state ) do
      push_sum(rec_s,rec_w,mates,pid ,i,j)
      {:noreply,state}
    end

  # GOSSIP #############################################################################################

  # GOSSIP - RECIEVE Main 
  def handle_cast({:message_gossip, _received}, [status,count,sent,n,x| mates ] =state ) do   
    length = round(Float.ceil(:math.sqrt(n)))
    i = rem(x-1,length) + 1
    j = round(Float.floor(((x-1)/length))) + 1
    case count < 200 do
      true ->  GenServer.cast(Master,{:received, [{i,j}]}) 
               gossip(x,mates,self(),n,i,j)
      false -> GenServer.cast(Master,{:hibernated, [{i,j}]})
    end 
    {:noreply,[status,count+1 ,sent,n, x  | mates]}  
  end

  # GOSSIP  - SEND Main
  def gossip(x,mates,pid, n,i,j) do
    the_one = the_chosen_one(mates)
    case GenServer.call(the_one,:is_active) do
      Active -> GenServer.cast(the_one, {:message_gossip, :_sending})
      ina_xy -> GenServer.cast(Master,{:droid_inactive, ina_xy})
                new_mate = GenServer.call(Master,:handle_node_failure)
                GenServer.cast(self(),{:remove_mate,the_one})
                GenServer.cast(self(),{:add_new_mate,new_mate})
                GenServer.cast(self(),{:retry_gossip,{pid,i,j}})
    end
  end

  # GOSSIP - HANDLE FAILURE SEND retry in case the Node is inactive
  def handle_cast({:retry_gossip, {pid,i,j}}, [status,count,sent,n,x| mates ] =state ) do   
    gossip(x,mates,pid, n,i,j)
    {:noreply,state}
  end

  # NODE ##########################################################################################

  # NODE : Checking status - Alive or Not
  def handle_call(:is_active , _from, state) do
    {status,n,x} =
      case state do
        [status,count,streak,prev_s_w,0, s ,w, n, x | mates ] -> {status,n,x}
        [status,count,sent,n,x| mates ] -> {status,n,x}
      end
    case status == Active do
      true -> {:reply, status, state }
      false -> 
        length = round(Float.ceil(:math.sqrt(n)))
        i = rem(x-1,length) + 1
        j = round(Float.floor(((x-1)/length))) + 1
        {:reply, [{i,j}], state }
    end
  end

  # NODE : Deactivation
  def handle_cast({:deactivate, _},[ status |tail ] ) do   
    {:noreply,[ Inactive | tail]}  
  end

  # NODE : REMOVE inactive node from network
  def handle_cast({:remove_mate, droid}, state ) do   
    new_state = List.delete(state,droid)
    {:noreply,new_state}  
  end

  # NODE : ADD another node to replace inactive node
  def handle_cast({:add_new_mate, droid}, state ) do   
    {:noreply, state ++ [droid]}  
  end

  # NETWORK #############################################################################################

  # NETWORK : Creating Network
  def create_network(n, is_push_sum \\ 0) do
    droids =
      for x <- 1..n do
        name = droid_name(x)
        GenServer.start_link(Line, [x,n, is_push_sum], name: name)
        name
      end
    GenServer.cast(Master,{:droids_update,droids})
  end

  # NETWORK : Naming the node
  def droid_name(x) do
    a = x|> Integer.to_string |> String.pad_leading(7,"0")
    "Elixir.D"<>a
    |>String.to_atom
  end

  # NETWORK : Defining and assigning Neighbors
  def droid_mates(self,n) do
    case self do
      1 -> [droid_name(n), droid_name(2)] 
      ^n -> [droid_name(n-1), droid_name(1)]
      _ -> [droid_name(self-1), droid_name(self+1)]
    end
  end

  # NETWORK : Choosing a neigbor randomly to send message to
  def the_chosen_one(neighbors) do
    Enum.random(neighbors)
  end

end
