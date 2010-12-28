class AddAiFieldToPlayers < ActiveRecord::Migration
  def self.up
  	add_column :players, :ai, :boolean, :default => false
  end

  def self.down
  	remove_column :players, :ai
  end
end
