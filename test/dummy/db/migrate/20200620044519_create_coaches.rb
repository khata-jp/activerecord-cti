class CreateCoaches < ActiveRecord::Migration[6.0]
  def change
    create_table :coaches do |t|
      t.integer :person_id
      t.string :licence_name

      t.timestamps
    end
  end
end
