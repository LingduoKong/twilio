class AddIndex < ActiveRecord::Migration
  def change
    add_index("users", "number")
  end
end
