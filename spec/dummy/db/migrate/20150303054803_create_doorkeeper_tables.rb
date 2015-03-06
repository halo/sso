# POI

# This migration file is created when you run `rails generate doorkeeper:install` in your OAuth Server Rails app.
# These tables are needed for Doorkeeper to work, see also https://github.com/doorkeeper-gem/doorkeeper#installation
# This migration here has *not* been modified. You simply see the original file below, created by the Doorkeeper generator.

# Note, however, that it was generated with Doorkeeper >= 2.0.0, since it has the `scopes` column on the `oauth_applications` table.
# We make use of that column and it was introduced here: https://github.com/doorkeeper-gem/doorkeeper/blob/master/CHANGELOG.md#200

class CreateDoorkeeperTables < ActiveRecord::Migration
  def change
    create_table :oauth_applications do |t|
      t.string  :name,         null: false
      t.string  :uid,          null: false
      t.string  :secret,       null: false
      t.text    :redirect_uri, null: false
      t.string  :scopes,       null: false, default: ''   # <- Exists only with Doorkeeper 2.0.0 or higher.
      t.timestamps null: false
    end

    add_index :oauth_applications, :uid, unique: true

    create_table :oauth_access_grants do |t|
      t.integer  :resource_owner_id, null: false
      t.integer  :application_id,    null: false
      t.string   :token,             null: false
      t.integer  :expires_in,        null: false
      t.text     :redirect_uri,      null: false
      t.datetime :created_at,        null: false
      t.datetime :revoked_at
      t.string   :scopes
    end

    add_index :oauth_access_grants, :token, unique: true

    create_table :oauth_access_tokens do |t|
      t.integer  :resource_owner_id
      t.integer  :application_id
      t.string   :token,             null: false
      t.string   :refresh_token
      t.integer  :expires_in
      t.datetime :revoked_at
      t.datetime :created_at,        null: false
      t.string   :scopes
    end

    add_index :oauth_access_tokens, :token, unique: true
    add_index :oauth_access_tokens, :resource_owner_id
    add_index :oauth_access_tokens, :refresh_token, unique: true
  end
end
