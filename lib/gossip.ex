defmodule Gossip do
  
  def observer() do
    GenServer.start_link(Gossip,:master, name: Master)
  end
    
  def init(:master) do
    {:ok, [[],[],0,0] }
  end

  def handle_cast({:received, droid }, [received, hibernated, r_count, h_count]) do
    case rem(r_count,100)==0 do
      true -> Task.start(Gossip,:draw_image,[received,hibernated,r_count])
      false ->" "
    end
    
    {:noreply,[received ++ droid, hibernated, r_count + 1,h_count]}
  end

  def handle_cast({:hibernated, droid }, [received, hibernated, r_count, h_count]) do
    {:noreply,[received, hibernated ++ droid, r_count, h_count + 1]}
    
  end

  def draw_image(received, hibernated, r_count) do
    image = :egd.create(400, 400)
    fill1 = :egd.color({250,70,22})
    fill2 = :egd.color({0,33,164})    
    Enum.each received, fn({first,second}) ->
      :egd.rectangle(image, {first*4-2, second*4-2},{first*4,second*4}, fill1)
    end
    Enum.each hibernated, fn({first,second}) ->
      :egd.filledRectangle(image, {first*4-2, second*4-2},{first*4,second*4}, fill2)
    end    
    rendered_image = :egd.render(image)
    File.write("live.png",rendered_image)
    File.write("snap#{r_count}.png",rendered_image)
  end



  def test() do
    received = [{5,1}]

    image = :egd.create(100, 100)
    fill1 = :egd.color({0,127,0})    
    font = :egd_font.load({:courier,[:bold,:italic],6})
    Enum.each received, fn({first,second}) ->
      #:egd.filledRectangle(image, {first*4-2, second*4-2},{first*4,second*4}, fill1)
      :egd.text(image, {first*4-2, second*4-2}, Font, "HELLO", fill1)
    end
     
    rendered_image = :egd.render(image)
    File.write("test.png",rendered_image)
  end
end