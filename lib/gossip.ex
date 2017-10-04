defmodule Gossip do
  # project2 numNodes topology algorithm
  def main(numNodes, topology, algorithm) do
    size =  round(Float.ceil(:math.sqrt(numNodes)))
    Gossip.observer(size)
    case algorithm do
      "gossip" ->
        case topology do
        "line" -> Line.create_network(numNodes, 0)
                  GenServer.cast(Line.droid_name(round(1)),{:message_gossip, :_sending})
        "grid" -> Grid.create_network(size,false, 0)
                  GenServer.cast(Grid.droid_name(round(size/2),round(size/2)),{:message_gossip, :_sending})
        "i_grid" -> Grid.create_network(size,true, 0)
                  GenServer.cast(Grid.droid_name(round(size/2),round(size/2)),{:message_gossip, :_sending})
        "full" -> Full.create_network(numNodes, 0)
                  GenServer.cast(Full.droid_name(round(numNodes/2)),{:message_gossip, :_sending})
        end
      "pushsum" -> 
        case topology do
          "line" -> Line.create_network(numNodes, 1)
                    GenServer.cast(Line.droid_name(round(numNodes/2)),{:message_push_sum, { 0, 0}})
          "grid" -> Grid.create_network(size,false, 1)
                    GenServer.cast(Grid.droid_name(round(size/2),round(size/2)),{:message_push_sum, { 0, 0}})
          "grid" -> Grid.create_network(size,true, 1)
                    GenServer.cast(Grid.droid_name(round(size/2),round(size/2)),{:message_push_sum, { 0, 0}})
          "full" -> Full.create_network(numNodes, 1)
                    GenServer.cast(Full.droid_name(round(numNodes/2)),{:message_push_sum, { 0, 0}})
        end
    end
  end
  
  def observer(size) do
    GenServer.start_link(Gossip,size, name: Master)
  end
    
  def init(size) do
    {:ok, [1,[],[],[{1,1}],[{1,1}],0,0,size,1] }
  end

  def handle_cast({:received, droid }, [cast_num,received, hibernated, prev_droid, prev_droid_2,r_count, h_count,size, draw_every]) do
    draw_every_=
      case cast_num == draw_every * 10 do
        true-> draw_every * 5
        false -> draw_every
      end
    case rem(cast_num,draw_every)==0 do
      true -> draw_image(received,hibernated,0,droid,prev_droid,prev_droid_2,size,cast_num)
      false-> ""
    end
    {:noreply,[cast_num+1,received ++ droid, hibernated, droid, prev_droid, r_count + 1,h_count,size,draw_every_]}
  end

  def handle_cast({:hibernated, droid }, [cast_num,received, hibernated,prev_droid, prev_droid_2, r_count, h_count,size, draw_every]) do
    draw_image(received,hibernated,1,droid,prev_droid, prev_droid_2,size,cast_num)
    {:noreply,[cast_num+1,received, hibernated ++ droid,droid, prev_droid, r_count, h_count + 1,size,draw_every]}
  end

  def draw_image(received, hibernated, terminated,droid,prev_droid, prev_droid_2, size,cast_num) do
    image = :egd.create(8*(size+1), 8*(size+1))
    fill1 = :egd.color({250,70,22})
    fill2 = :egd.color({0,33,164})
    fill3 = :egd.color({255,0,0})    
    Enum.each received, fn({first,second}) ->
      :egd.rectangle(image, {first*8-2, second*8-2},{first*8,second*8}, fill1)
    end
    # Enum.each hibernated, fn({first,second}) ->
    #   :egd.filledRectangle(image, {first*8-2, second*8-2},{first*8,second*8}, fill2)
    # end
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
        :egd.filledEllipse(image,{first*8-4,second*8-4},{first*8+2,second*8+2}, fill3)
    end

    
    rendered_image = :egd.render(image)
    File.write("live.png",rendered_image)
    File.write("SS/snap#{cast_num}.png",rendered_image)
  end



  def test() do
    
    length = 100
    received = 
      for x <- 1..100  do
        i = rem(x-1,length) + 1
        j = round(Float.floor(((x-1)/length))) + 1
        {i,j}
      end

    image = :egd.create(101*4, 101*4)
    fill1 = :egd.color({0,127,0})    
    #font = :egd_font.glyph({:courier,[:bold,:italic],6})
    Enum.each received, fn({first,second}) ->
      :egd.filledRectangle(image, {first*4-2, second*4-2},{first*4,second*4}, fill1)
     # :egd.text(image, {first*4-2, second*4-2}, Font, "HELLO", fill1)
    end
     
    rendered_image = :egd.render(image)
    File.write("test.png",rendered_image)
  end
end