class CreateReconciliationWorkbench < ActiveRecord::Migration[8.1]
  def change
    create_table :reconciliation_rule_decisions do |t|
      t.string :rule_key, null: false
      t.integer :rule_version, null: false
      t.string :decision, null: false
      t.json :case_fingerprints, null: false, default: []
      t.text :comment
      t.references :user, foreign_key: true
      t.timestamps
    end
    add_index :reconciliation_rule_decisions, [:rule_key, :rule_version], unique: true,
              name: 'index_reconciliation_decisions_on_rule'
    create_table :reconciliation_cases do |t|
      t.string :axis, null: false
      t.string :rule_key, null: false
      t.integer :rule_version, null: false
      t.string :case_key, null: false
      t.string :fingerprint, null: false
      t.string :status, null: false, default: 'pending'
      t.boolean :active, null: false, default: true
      t.json :payload, null: false, default: {}
      t.json :result, null: false, default: {}
      t.text :error
      t.integer :attempts, null: false, default: 0
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
    end
    add_index :reconciliation_cases, [:rule_key, :case_key, :fingerprint], unique: true,
              name: 'index_reconciliation_cases_on_identity'
    add_index :reconciliation_cases, [:active, :axis, :rule_key, :status],
              name: 'index_reconciliation_cases_on_work'
    create_table :reconciliation_runs do |t|
      t.string :status, null: false, default: 'queued'
      t.string :mode, null: false, default: 'refresh'
      t.string :rule_key
      t.references :user, foreign_key: true
      t.json :summary, null: false, default: {}
      t.text :error
      t.boolean :stop_requested, null: false, default: false
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
    end
    add_index :reconciliation_runs, [:status, :created_at]
    create_table :reconciliation_record_changes do |t|
      t.bigint :record_id, null: false
      t.references :reconciliation_case, null: false, foreign_key: true
      t.string :before_digest, null: false
      t.string :after_digest, null: false
      t.json :after_snapshot, null: false
      t.timestamps
    end
    add_index :reconciliation_record_changes, [:record_id, :id]
  end
end
