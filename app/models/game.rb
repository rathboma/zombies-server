class Game < ActiveRecord::Base
  attr_accessible :player1_id, :player2_id
  scope :waiting, :conditions => ["player1_id IS NULL OR player2_id IS NULL"]
  has_one :game_board

  COSTS = { "V" => 1, "C" => 2, "S" => 3 }
  PRICES = { "V" => 1.5, "C" => 4, "S" => 4.5 }

  def self.new_with_game_board(ai = false)
    game = new
    game.game_board = GameBoard.create(:x => 21, :y => 21)
    if ai
      aiPlayer = Player.new(:name => "AI", :ai => true)
      aiPlayer.setup(game.game_board.initial_tile)
      aiPlayer.save!
      game.add_player!(aiPlayer)
    end
    game
  end

  def move_error
    @error
  end

  def error
    @error
  end
  
  def add_player!(p)
    if !player1_id
      puts "adding player one: #{p.inspect}"
      self.player1_id = p.id
    elsif !player2_id
      puts "adding player two: #{p.inspect}"
      self.player2_id = p.id
    else
      puts "ERROR: This game already has two players!"
    end
    self.save!
    p.game_id = self.id
    p.save!
  end

  def turns_remaining
    (player1 && player2) ? player1.turns_remaining + player2.turns_remaining : nil
  end

  def current_player
    [player1, player2].select(&:turn?).first
  end

  def player1
    @player1 ||= Player.find(self.player1_id) if player1_id
  end

  def player2
    @player2 ||= Player.find(self.player2_id) if player2_id
  end

  def other_player(p)
    (p == player1) ? player2 : player1
  end

  def game_over?
    turns_remaining != nil && self.turns_remaining <= 0
  end

  def won?(p)
    other = other_player(p)
    if p.nil? || other.nil?
      false
    elsif self.turns_remaining > 0
      false
    else
      p.get_score > other.get_score
    end
  end

  def move(player, x, y)
    x = x.to_i
    y = y.to_i
    unless x < game_board.x && x >= 0 && y >= 0 && y < game_board.y
      @error = "co-ordinates not on the game board"
      return nil
    end

    unless player.can_move?
      @error = "it is not this players turn to move"
      return nil
    end

    if (player.x - x ).abs + (player.y - y).abs > 1
      @error = "you can only move one tile at a time"
      return nil
    end

    player.can_move = false
    player.can_act = true
    player.update_position(x, y)
    player.save!

    tile = game_board.tiles.with_coordinates(x, y).first || Tile.generate!(x, y, :game_board_id => game_board.id)
    puts tile
    #check x, y are valid
    #try to find tile
    # if tile doesn't exist - generate tile, save it
    # return tile
    tile
  end

  def ready?
    player1_id && player2_id
  end

  def start_game
    player1.update_attributes(:can_move => true)
  end  

  def action_result(player, tile)
    { :player => player.to_hash,
      :tile => tile.to_hash }
  end

  def kill(player)
    @player = player
    tile = @player.game.game_board.tiles.with_coordinates(@player.x, @player.y).first()
    unless tile
      @error = "tile not found"
      return nil
    end
    tile.update_attributes(:zombies => tile.zombies - 1) if tile.zombies > 0
    @player.update_attributes(:can_act => false, :turns_remaining => @player.turns_remaining - 1, :kills => @player.kills + 1)
    @player.game.other_player(@player).update_attributes(:can_move => true)
    action_result(@player, tile)
  end

  def buy(player, flavor, num)
    num = num.abs

    if !PRICES[flavor]
      @error = 'not a valid ice-cream'
      return nil
    end

    @tile = game_board.tiles.with_coordinates(player.x, player.y).first()
    unless @tile.store?
      @error = 'you are not on a store'
      return nil
    end
    # validate the player is on a store
    # validate the player has enough money
    amount = COSTS[flavor]*num
    if amount > player.money
      @error = 'not enough money'
      return nil
    end

    player[flavor] = player[flavor] + num
    player.money -= amount
    finish_action(player)
    player.save!
    #ok
    action_result(player, @tile)
  end

  def sell(player, flavor, number, customer_id)
    @player = player
    tile = @player.game.game_board.tiles.with_coordinates(@player.x, @player.y).first()
    begin
      @customer = tile.customers.find(customer_id)
    rescue ActiveRecord::RecordNotFound
      @error = "Could not find customer"
      return nil
    end

    flavors = PRICES.keys + [@customer.favorite_type]
    prices = PRICES.merge({@customer.favorite_type => @customer.favorite_price})

    if tile.zombies > 0
      @error = "you cannot sell to customers when there are zombies around!"
      return nil
    end

    if !flavors.include?(flavor)
      @error = "invalid ice cream combo specified, only valid: #{base_flavors.inspect}"
      return nil
    end

    to_sell = flavor.split(/,\s*/)
    if (!@customer.can_consume?(flavor, number))
      @error = "you can't sell that many ice creams"
      return nil
    end

    to_sell.each do |flav|#stuff
      @player[flav] -= number
      if @player[flav] < 0
        @error = "you don't have that many ice-creams to sell"
        return nil
      end
    end

    @player.money += prices[flavor]*number
    @player.sales += 1
    @customer.destroy
    finish_action(@player)
    action_result(@player, tile)
  end

  def finish_action(player)
    player.can_act = false
    player.turns_remaining -= 1
    player.save!
    player.game.other_player(player).update_attributes(:can_move => true)
  end
end
