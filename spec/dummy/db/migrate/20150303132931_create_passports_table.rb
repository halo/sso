# POT

class CreatePassportsTable < ActiveRecord::Migration
  # TODO: Right now this requires Postgres
  def change
    enable_extension 'uuid-ossp'

    create_table :passports, id: :uuid do |t|
      t.integer :oauth_access_grant_id
      t.integer :oauth_access_token_id
      t.integer :application_id, null: false
      t.integer :owner_id, null: false
      t.string :group_id, null: false
      t.string :secret, null: false, unique: true
      t.inet :ip, null: false
      t.string :agent
      t.string :location
      t.datetime :activity_at, null: false
      t.datetime :revoked_at
      t.string :revoke_reason
      t.timestamps null: false
    end

    add_index :passports, [:owner_id, :oauth_access_token_id], where: 'revoked_at IS NULL AND oauth_access_token_id IS NOT NULL', unique: true, name: :one_access_token_per_owner

    add_index :passports, :oauth_access_grant_id
    add_index :passports, :oauth_access_token_id
    add_index :passports, :application_id
    add_index :passports, :owner_id
    add_index :passports, :group_id
    add_index :passports, :secret
    add_index :passports, :ip
    add_index :passports, :revoke_reason
  end
end
