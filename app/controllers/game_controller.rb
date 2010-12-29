class GameController < ApplicationController
  include AIPlayer

  respond_to :json
  skip_before_filter :verify_authenticity_token
  #post
  before_filter :set_default_response_format

  def set_default_response_format
    request.format = :json if params[:format].nil?
  end

  def play_ai_turns(game)
    while game.ready? && game.current_player && game.current_player.ai && !game.game_over?
      aiPlayer = game.current_player
      ai = AIPlayer::Client.new
      move = ai.make_move!(JsonGame.new(aiPlayer, game.game_board, game.other_player(aiPlayer), game.game_over?, game.won?(aiPlayer)))
      puts "AI MAKING THE MOVE: #{move.inspect}"
      tile = game.move(aiPlayer, move[:x], move[:y])
      act = ai.take_action!({:tile => tile.to_hash, :player => aiPlayer.to_hash}.to_json)
      puts "AI TAKING THE ACTION: #{act.inspect}"
      if act[:action] == :kill
        game.kill(aiPlayer)
      elsif act[:action] == :sell
        game.sell(aiPlayer, act[:flavor], act[:number], act[:customer_id])
      elsif act[:action] == :buy
        game.buy(aiPlayer, act[:flavor], act[:number].to_i.abs)
      elsif act[:action] == :run
        game.kill(aiPlayer) # Lol kill instead of run. whatever
      end
    end
  end

  def join
    debug = params[:debug]
    ai = params[:ai]
    game = Game.waiting.last()
    if !game || debug
      game = Game.new_with_game_board(ai || debug)
    end

    game.save!
    @player = Player.new(:name => params[:name])
    @player.setup(game.game_board.initial_tile)
    @player.save!

    game.add_player!(@player)
    game.start_game if game.ready?
    game.save!
    render :json => {:uuid => @player.uuid}
    play_ai_turns(@player.game)
  end

  #get
  def get_turn
    @player = Player.find_by_uuid(params[:uuid])
    if !@player
      render :json => {:error => "player not found"}
      return
    end
    render :json => {:turn => @player.turn?}
  end

  #sends player.uuid
  def get_game_state
    @player = Player.find_by_uuid(params[:uuid])
    unless @player
      respond_with({:error => "player not found"}) 
      return
    end
    @game = @player.game
    resp_obj  = JsonGame.new(@player, @game.game_board, @game.other_player(@player), @game.game_over?, @game.won?(@player))
    respond_with (resp_obj)
    # get game.gamestate
  end

  #params: uuid, x, y
  def post_make_move
    #moves to a new tile : if tile doesn't exist, create the tile and add it to the game_state
    @player = Player.find_by_uuid(params[:uuid])
    @game = @player.game
    play_ai_turns(@player.game)

    if !@player
      render :json => {:error => "not a valid player UUID"}
      return
    end

    if @tile = @game.move(@player, params[:x], params[:y])
      render :json => {:tile => @tile.to_hash, :player => @player.to_hash}
    else
      render :json => {:error => @game.move_error}
    end

    play_ai_turns(@player.game)
  end

  #params = uuid, type, details
  def validate_action!
    uuid = params[:uuid]
    @player = Player.find_by_uuid(uuid)
    play_ai_turns(@player.game)

    if !uuid || !@player
      render :json => {:error => "you didn't supply a valid UUID"}
      puts "invalid"
      return false
    end

    if !@player.can_act
      render :json => {:error => "this player is not allowed to act"}
      puts "also invalid"
      return false
    end
    true
  end

  def kill
    return unless validate_action!()
    puts "validated"
    response = @player.game.kill(@player)
    render :json => response.nil? ? {:error => @player.game.error} : response
    play_ai_turns(@player.game)
  end

  def sell
    return unless validate_action!()
    flavors = params[:flavors]
    number = params[:number].to_i.abs
    customer_id = params[:customer_id].to_i
    response = @player.game.sell(@player, flavors, number, customer_id)
    puts "I got here"
    puts response
    render :json => response.nil? ? {:error => @player.game.error} : response
    play_ai_turns(@player.game)
  end

  def buy
    return unless validate_action!()
    flavor = params[:flavor]
    num = params[:number].to_i.abs
    uuid = params[:uuid]

    if !flavor || !num
      render :json => {:error => "didn't supply either the flavor, or the number to buy"}
      return
    end

    response = @player.game.buy(@player, flavor, num)
    render :json => response.nil? ? {:error => @player.game.error} : response
    play_ai_turns(@player.game)
  end

  def run
    return unless validate_action!()
    #TODO
    play_ai_turns(@player.game)
  end
end
