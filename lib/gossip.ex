defmodule Gossip do
  use GenServer
  # MAIN : Distributing the work based on user input
  
  def main(args) do
    case length(args) do
      3 -> 
        [numNodes_, topology, algorithm] = args
        {numNodes,_} = Integer.parse(numNodes_)
        percentage = 0 
      4 ->
        [numNodes_, topology, algorithm, percentage_ ] = args
        {numNodes,_} = Integer.parse(numNodes_)
        {percentage,_} = Integer.parse(percentage_)
      _ -> IO.puts("please recheck your entry")
    end
    main_(numNodes, topology, algorithm, percentage)
  end

  def main(numNodes, topology, algorithm, percentage \\ 0) do
    main_(numNodes, topology, algorithm, percentage)
  end

  def main_(numNodes, topology, algorithm, percentage) do
    size =  round(Float.ceil(:math.sqrt(numNodes)))
    Gossip.observer(size)
    case algorithm do
      "gossip" ->
        case topology do
        "line"   -> Line.create_network(numNodes, 0)
                    deactivate(percentage)
                    GenServer.cast(Line.droid_name(round(1)),{:message_gossip, :_sending})
        "grid"   -> Grid.create_network(size,false, 0)
                    deactivate(percentage)
                    GenServer.cast(Grid.droid_name(round(size/2),round(size/2)),{:message_gossip, :_sending})
        "i_grid" -> Grid.create_network(size,true, 0)
                    deactivate(percentage)
                    GenServer.cast(Grid.droid_name(round(size/2),round(size/2)),{:message_gossip, :_sending})
        "full"   -> Full.create_network(numNodes, 0)
                    deactivate(percentage)
                    GenServer.cast(Full.droid_name(round(numNodes/2)),{:message_gossip, :_sending})
        end
      "pushsum" -> 
        case topology do
          "line"   -> Line.create_network(numNodes, 1)
                      deactivate(percentage)
                      GenServer.cast(Line.droid_name(round(numNodes/2)),{:message_push_sum, { 0, 0}})
          "grid"   -> Grid.create_network(size,false, 1)
                      deactivate(percentage)
                      GenServer.cast(Grid.droid_name(round(size/2),round(size/2)),{:message_push_sum, { 0, 0}})
          "i_grid" -> Grid.create_network(size,true, 1)
                      deactivate(percentage) 
                      GenServer.cast(Grid.droid_name(round(size/2),round(size/2)),{:message_push_sum, { 0, 0}})
          "full"   -> Full.create_network(numNodes, 1)
                      deactivate(percentage)
                      GenServer.cast(Full.droid_name(round(numNodes/2)),{:message_push_sum, { 0, 0}})
        end
    end
    Process.sleep(:infinity)
  end

  ####################################################################################
  
  def observer(size) do
    GenServer.start_link(Gossip,size, name: Master)
  end

  def deactivate(percentage) do
    case percentage do
      0 -> ""
      num -> GenServer.cast(Master,{:deactivate, percentage})
    end
  end

  ######################################################################################
    
  def init(size) do
    {:ok, [1,[],[],[{1,1}],[{1,1}],0,0,size,1,0,[],[] ]} #[cast_number, nodes_recieved, nodes_hibernated, prev_droid, prev_to_prev_droid, recieve_count, hibernation_count]
  end

  # NODES - deactivate percentage of nodes
  def handle_cast({:deactivate, percentage }, [_cast_num,_received, _hibernated,_prev_droid, _prev_droid_2, _r_count, _h_count,size, _draw_every,_init_time, droids, dead_droids]) do
    num_deactivate = round(size*size*percentage / 100)
    to_deactivate = Enum.take_random(droids,num_deactivate)
    IO.puts("deactivated: #{inspect to_deactivate} ")
    Enum.each to_deactivate, fn( droid ) -> 
      GenServer.cast(droid,{:deactivate, :you_are_getting_deactivated })
    end
    {:noreply,[_cast_num,_received, _hibernated,_prev_droid, _prev_droid_2, _r_count, _h_count,size,_draw_every,_init_time,droids, dead_droids]}
  end
 
  # NETWORK - update state with the active droids
  def handle_cast({:droids_update, droids_update }, [_cast_num,_received, _hibernated,_prev_droid, _prev_droid_2, _r_count, _h_count,_size, _draw_every,_init_time, droids, dead_droids]) do
    {:noreply,[_cast_num,_received, _hibernated,_prev_droid, _prev_droid_2, _r_count, _h_count,_size,_draw_every,_init_time,droids_update,dead_droids]}
  end

  # HANDLE FAILURE - updating the droids that received the message
  def handle_cast({:received, droid }, [cast_num,received, hibernated, prev_droid, prev_droid_2,r_count, h_count,size, draw_every,init_time,_droids ,dead_droids]) do
    init_time_ = 
      case cast_num do
        1 -> DateTime.utc_now()
        _ -> init_time 
      end
    draw_every_=
      case cast_num == draw_every * 10 do
        true-> draw_every * 5
        false -> draw_every
      end
    case rem(cast_num,draw_every)==0 do
      true -> Task.start(Gossip,:draw_image,[received,hibernated,0,droid,prev_droid,prev_droid_2,size,cast_num,dead_droids])
      false-> ""
    end
    {:noreply,[cast_num+1,received ++ droid, hibernated, droid, prev_droid, r_count + 1,h_count,size,draw_every_,init_time_,_droids, dead_droids]}
  end

  # HANDLE FAILURE - updating the messages that received the message
  def handle_cast({:hibernated, droid }, [cast_num,received, hibernated,prev_droid, prev_droid_2, r_count, h_count,size, draw_every,init_time, droids,dead_droids]) do
    #draw_image(received,hibernated,1,droid,prev_droid, prev_droid_2,size,cast_num,dead_droids)
    end_time = DateTime.utc_now
    convergence_time=DateTime.diff(end_time,init_time,:millisecond)
    IO.puts("Convergence time: #{convergence_time} ms")
    draw_image(received,hibernated,1,droid,prev_droid, prev_droid_2,size,cast_num, dead_droids)
    {:noreply,[cast_num+1,received, hibernated ++ droid,droid, prev_droid, r_count, h_count + 1,size,draw_every,init_time,droids,dead_droids]}
  end

  # NODE - provide new neighbor to node that lost one neighbor due to failure
  def handle_call(:handle_node_failure, {pid,_} ,[_cast_num,_received, _hibernated,_prev_droid, _prev_droid_2, _r_count, _h_count,_size, _draw_every,_init_time, droids,dead_droids]) do
    #IO.puts("inspecting #{inspect _from}")
    new_droid = Enum.random(droids)
    case :erlang.whereis(new_droid) do
      ^pid -> new_droid = List.delete(droids,new_droid) |> Enum.random
      _ -> ""
    end
    {:reply,new_droid,[_cast_num,_received, _hibernated,_prev_droid, _prev_droid_2, _r_count, _h_count,_size,_draw_every,_init_time,droids,dead_droids]}
  end

  # NETWORK - update network with to highlight the inactive droids
  def handle_cast({:droid_inactive, droid },[_cast_num,_received, _hibernated,_prev_droid, _prev_droid_2, _r_count, _h_count,_size, _draw_every,_init_time, droids,dead_droids]) do
    {:noreply,[_cast_num,_received, _hibernated,_prev_droid, _prev_droid_2, _r_count, _h_count,_size,_draw_every,_init_time,List.delete(droids,droid),dead_droids ++ droid]}
  end

  # plots diagram at given instants of the whole network
  def draw_image(received, hibernated, terminated,droid,prev_droid, prev_droid_2, size,cast_num, dead_droids) do
    image = :egd.create(8*(size+1), 8*(size+1))
    fill1 = :egd.color({250,70,22})
    fill2 = :egd.color({0,33,164})
    fill3 = :egd.color({255,0,0})  
    fill4 = :egd.color({0,0,0})    
    Enum.each received, fn({first,second}) ->
      :egd.rectangle(image, {first*8-2, second*8-2},{first*8,second*8}, fill1)
    end

    [{ first, second }] = prev_droid_2
    :egd.filledEllipse(image,{first*8-2,second*8-2},{first*8,second*8}, fill2)
    [{ first, second }] = prev_droid
    :egd.filledEllipse(image,{first*8-3,second*8-3},{first*8+1,second*8+1}, fill2)
    case terminated do
      0 -> 
        [{ first, second }] = droid
        :egd.filledEllipse(image,{first*8-4,second*8-4},{first*8+2,second*8+2}, fill2)
      1 ->
        [{ first, second }] = droid
        :egd.filledEllipse(image,{first*8-6,second*8-6},{first*8+4,second*8+4}, fill3)
    end

    Enum.each dead_droids, fn({first,second}) ->
      :egd.filledRectangle(image, {first*8-3, second*8-3},{first*8+1,second*8+1}, fill4)
    end

    
    rendered_image = :egd.render(image)
    File.write("live.png",rendered_image)
    File.write("SS/snap#{cast_num}.png",rendered_image)
  end

end