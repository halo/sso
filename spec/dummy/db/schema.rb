# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20150303132931) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "uuid-ossp"
  enable_extension "hstore"

  create_table "oauth_access_grants", force: :cascade do |t|
    t.integer  "resource_owner_id", null: false
    t.integer  "application_id",    null: false
    t.string   "token",             null: false
    t.integer  "expires_in",        null: false
    t.text     "redirect_uri",      null: false
    t.datetime "created_at",        null: false
    t.datetime "revoked_at"
    t.string   "scopes"
  end

  add_index "oauth_access_grants", ["token"], name: "index_oauth_access_grants_on_token", unique: true, using: :btree

  create_table "oauth_access_tokens", force: :cascade do |t|
    t.integer  "resource_owner_id"
    t.integer  "application_id"
    t.string   "token",             null: false
    t.string   "refresh_token"
    t.integer  "expires_in"
    t.datetime "revoked_at"
    t.datetime "created_at",        null: false
    t.string   "scopes"
  end

  add_index "oauth_access_tokens", ["refresh_token"], name: "index_oauth_access_tokens_on_refresh_token", unique: true, using: :btree
  add_index "oauth_access_tokens", ["resource_owner_id"], name: "index_oauth_access_tokens_on_resource_owner_id", using: :btree
  add_index "oauth_access_tokens", ["token"], name: "index_oauth_access_tokens_on_token", unique: true, using: :btree

  create_table "oauth_applications", force: :cascade do |t|
    t.string   "name",                      null: false
    t.string   "uid",                       null: false
    t.string   "secret",                    null: false
    t.text     "redirect_uri",              null: false
    t.string   "scopes",       default: "", null: false
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
  end

  add_index "oauth_applications", ["uid"], name: "index_oauth_applications_on_uid", unique: true, using: :btree

  create_table "passports", id: :uuid, default: "uuid_generate_v4()", force: :cascade do |t|
    t.integer  "oauth_access_grant_id"
    t.integer  "oauth_access_token_id"
    t.boolean  "insider"
    t.integer  "owner_id",              null: false
    t.string   "secret",                null: false
    t.datetime "activity_at",           null: false
    t.inet     "ip",                    null: false
    t.string   "agent"
    t.string   "location"
    t.string   "device"
    t.hstore   "stamps"
    t.datetime "revoked_at"
    t.string   "revoke_reason"
    t.datetime "created_at",            null: false
    t.datetime "updated_at",            null: false
  end

  add_index "passports", ["activity_at"], name: "index_passports_on_activity_at", using: :btree
  add_index "passports", ["device"], name: "index_passports_on_device", using: :btree
  add_index "passports", ["insider"], name: "index_passports_on_insider", using: :btree
  add_index "passports", ["ip"], name: "index_passports_on_ip", using: :btree
  add_index "passports", ["location"], name: "index_passports_on_location", using: :btree
  add_index "passports", ["oauth_access_grant_id"], name: "index_passports_on_oauth_access_grant_id", using: :btree
  add_index "passports", ["oauth_access_token_id"], name: "index_passports_on_oauth_access_token_id", using: :btree
  add_index "passports", ["owner_id", "oauth_access_token_id"], name: "one_access_token_per_owner", unique: true, where: "((revoked_at IS NULL) AND (oauth_access_token_id IS NOT NULL))", using: :btree
  add_index "passports", ["owner_id"], name: "index_passports_on_owner_id", using: :btree
  add_index "passports", ["revoke_reason"], name: "index_passports_on_revoke_reason", using: :btree
  add_index "passports", ["revoked_at"], name: "index_passports_on_revoked_at", using: :btree
  add_index "passports", ["secret"], name: "index_passports_on_secret", using: :btree

  create_table "users", force: :cascade do |t|
    t.string   "name",                    null: false
    t.string   "email",                   null: false
    t.string   "password",                null: false
    t.string   "tags",       default: [],              array: true
    t.boolean  "vip"
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
  end

end
