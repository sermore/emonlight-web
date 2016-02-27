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

ActiveRecord::Schema.define(version: 20160207214543) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "nodes", force: :cascade do |t|
    t.string   "title",                               null: false
    t.integer  "pulses_per_kwh",       default: 1000, null: false
    t.string   "authentication_token"
    t.integer  "user_id"
    t.datetime "created_at",                          null: false
    t.datetime "updated_at",                          null: false
    t.string   "time_zone"
    t.string   "dashboard"
  end

  add_index "nodes", ["user_id"], name: "index_nodes_on_user_id", using: :btree

  create_table "pulses", force: :cascade do |t|
    t.datetime "pulse_time", precision: 6
    t.float    "power"
    t.integer  "node_id"
  end

  add_index "pulses", ["node_id", "pulse_time"], name: "index_pulses_on_node_id_and_pulse_time", using: :btree
  add_index "pulses", ["node_id"], name: "index_pulses_on_node_id", using: :btree

  create_table "stat_values", force: :cascade do |t|
    t.integer "stat_id"
    t.integer "group_by"
    t.float   "mean",       default: 0.0, null: false
    t.float   "sum_weight", default: 0.0, null: false
  end

  add_index "stat_values", ["stat_id"], name: "index_stat_values_on_stat_id", using: :btree

  create_table "stats", force: :cascade do |t|
    t.integer  "node_id"
    t.integer  "stat"
    t.float    "mean",                     default: 0.0, null: false
    t.float    "sum_weight",               default: 0.0, null: false
    t.datetime "start_time", precision: 6
    t.datetime "end_time",   precision: 6
  end

  add_index "stats", ["node_id"], name: "index_stats_on_node_id", using: :btree

  create_table "users", force: :cascade do |t|
    t.string   "email",                  default: "", null: false
    t.string   "encrypted_password",     default: "", null: false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",          default: 0,  null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.inet     "current_sign_in_ip"
    t.inet     "last_sign_in_ip"
    t.datetime "created_at",                          null: false
    t.datetime "updated_at",                          null: false
    t.string   "name"
    t.integer  "node_id"
    t.string   "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
  end

  add_index "users", ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true, using: :btree
  add_index "users", ["email"], name: "index_users_on_email", unique: true, using: :btree
  add_index "users", ["node_id"], name: "index_users_on_node_id", using: :btree
  add_index "users", ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true, using: :btree

  add_foreign_key "nodes", "users"
  add_foreign_key "pulses", "nodes"
  add_foreign_key "stat_values", "stats"
  add_foreign_key "stats", "nodes"
  add_foreign_key "users", "nodes"
end
