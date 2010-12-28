class Customer < ActiveRecord::Base
  attr_accessible :favorite_type, :favorite_price, :favorite_number
  belongs_to :tile, :foreign_key => :tile_id

  TYPES = ["C", "S", "V", "C,S,V", "C,S", "C,V", "V,S", "C,C", "V,V", "S,S", "C,S,V,S,V", "S,S,S,S"]
  NUMS = [-1, 1, 2, 3, 4, 5]

  def self.generate
    c = new()
    c.favorite_type = TYPES[rand(TYPES.length - 1)]
    c.favorite_price = rand(40) + 2
    c.favorite_number = NUMS[rand(NUMS.length - 1)]
    c
  end

  def to_hash
    { :id => id,
      :favorite_type => favorite_type,
      :favorite_price => favorite_price,
      :favorite_number => favorite_number
    }
  end

  def can_consume?(flavor, number)
    if flavor == favorite_type && (favorite_number == -1 || favorite_number >= number)
      true
    elsif number == 1 && Game::PRICES.keys.include?(flavor)
      true
    else
      false
    end
  end
end
