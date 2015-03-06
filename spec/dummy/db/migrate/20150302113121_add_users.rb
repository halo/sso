# This is not part of SSO, this is simply an example implementation of a user model.

class AddUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :password, null: false  # <- Of course you would have this encrypted in a real-life setup
      t.string :tags, array: true, default: []
      t.boolean :vip
      t.timestamps null: false
    end
  end
end
