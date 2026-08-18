# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_08_06_151716) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "appointments", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.bigint "provider_profile_id", null: false
    t.bigint "service_id", null: false
    t.datetime "scheduled_at"
    t.integer "status"
    t.integer "modality"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_appointments_on_client_id"
    t.index ["provider_profile_id"], name: "index_appointments_on_provider_profile_id"
    t.index ["service_id"], name: "index_appointments_on_service_id"
  end

  create_table "provider_profiles", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.text "bio"
    t.string "address"
    t.string "city"
    t.string "category"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_provider_profiles_on_user_id"
  end

  create_table "services", force: :cascade do |t|
    t.bigint "provider_profile_id", null: false
    t.string "name"
    t.text "description"
    t.integer "duration"
    t.decimal "price"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["provider_profile_id"], name: "index_services_on_provider_profile_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "name"
    t.integer "role"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "appointments", "provider_profiles"
  add_foreign_key "appointments", "services"
  add_foreign_key "appointments", "users", column: "client_id"
  add_foreign_key "provider_profiles", "users"
  add_foreign_key "services", "provider_profiles"
end
