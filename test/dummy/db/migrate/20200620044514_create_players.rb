class CreatePlayers < ActiveRecord::Migration[6.0]
  def change
    create_table :players do |t|
      t.integer :person_id
      t.string :position_name

      t.timestamps
    end
  end
end
