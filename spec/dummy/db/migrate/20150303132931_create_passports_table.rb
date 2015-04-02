# POI

# This is what the Passport table on the SSO Server looks like. You need to have this migration.
# As you can see it uses the `uuid` and `inet` column types. So you are kind of stuck with Postgres.
# However, there should be no reason for you not to simply use `integer` and `string` for those two columns instead.

class CreatePassportsTable < ActiveRecord::Migration
  def change
    enable_extension 'uuid-ossp'
    enable_extension 'hstore'

    create_table :passports, id: :uuid do |t|
      # Relationships with Doorkeeper-internal tables
      t.integer :oauth_access_grant_id     # OAuth Grant Token
      t.integer :oauth_access_token_id     # OAuth Access Token
      t.boolean :insider                   # Denormalized: Is the client app trusted?

      # Passport information
      t.integer :owner_id, null: false               # User ID
      t.string :secret, null: false, unique: true    # Random secret string

      # Passport activity
      t.datetime :activity_at, null: false   # Timestamp of most recent usage
      t.inet :ip, null: false                # Most recent IP which used this Passport
      t.string :agent                        # Post recent User Agent which used this Passport
      t.string :location                     # Human-readable city of the IP (geolocation)
      t.string :device                       # Mobile client hardware UUID (if applicable)
      t.hstore :stamps                       # Keeping track of *all* IPs which use(d) this Passport

      # Revocation
      t.datetime :revoked_at                 # If set, consider this record to be deleted
      t.string :revoke_reason                # Slug describing why deleted (logout, timeout, etc)
      t.timestamps null: false               # Internal Rails created_at and updated_at columns
    end

    # Doorkeeper is not guaranteed to create a new access token upon each login, it may just return an existing one
    # That's why we need to check for `revoked_at`, only valid passports bear the constraint
    add_index :passports, [:owner_id, :oauth_access_token_id], where: 'revoked_at IS NULL AND oauth_access_token_id IS NOT NULL', unique: true, name: :one_access_token_per_owner

    add_index :passports, :oauth_access_grant_id
    add_index :passports, :oauth_access_token_id
    add_index :passports, :insider
    add_index :passports, :owner_id
    add_index :passports, :secret
    add_index :passports, :activity_at
    add_index :passports, :ip
    add_index :passports, :location
    add_index :passports, :device
    add_index :passports, :revoked_at
    add_index :passports, :revoke_reason
  end
end
