class CreateNumbers < ActiveRecord::Migration
  def change
    create_table :numbers do |t|
      t.string "number_id" 
      t.string "first_name"
      t.string "last_name"
      t.timestamps null: false
    end
  end
end
