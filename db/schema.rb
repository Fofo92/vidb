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

ActiveRecord::Schema[8.1].define(version: 2026_09_08_113405) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "countries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "flag"
    t.string "long_name"
    t.string "short_name"
    t.datetime "updated_at", null: false
  end

  create_table "countries_records", id: false, force: :cascade do |t|
    t.bigint "country_id", null: false
    t.bigint "record_id", null: false
  end

  create_table "genders", force: :cascade do |t|
    t.text "comment"
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "genders_records", id: false, force: :cascade do |t|
    t.bigint "gender_id", null: false
    t.bigint "record_id", null: false
  end

  create_table "language_versions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "long_name"
    t.string "short_name"
    t.datetime "updated_at", null: false
  end

  create_table "media", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "long_name"
    t.string "short_name"
    t.datetime "updated_at", null: false
  end

  create_table "media_records", id: false, force: :cascade do |t|
    t.bigint "medium_id", null: false
    t.bigint "record_id", null: false
  end

  create_table "records", force: :cascade do |t|
    t.text "abstract"
    t.string "ancestry"
    t.bigint "country_id"
    t.datetime "created_at", null: false
    t.string "french_title"
    t.boolean "is_available", default: false
    t.boolean "is_checked", default: false
    t.boolean "is_recorded"
    t.boolean "is_seen", default: false
    t.bigint "language_version_id"
    t.integer "length_in_mn"
    t.string "original_title"
    t.integer "rank"
    t.string "record_kind", default: "undetermined", null: false
    t.datetime "updated_at", null: false
    t.integer "year"
    t.index ["ancestry"], name: "index_records_on_ancestry"
    t.index ["country_id"], name: "index_records_on_country_id"
    t.index ["language_version_id"], name: "index_records_on_language_version_id"
    t.check_constraint "record_kind::text = ANY (ARRAY['undetermined'::character varying, 'standalone_video'::character varying, 'series'::character varying, 'season'::character varying, 'episode'::character varying]::text[])", name: "records_record_kind_check"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "records", "countries"
  add_foreign_key "records", "language_versions"
end
