class CreateReconciliationCaseReviews < ActiveRecord::Migration[8.1]
  def change
    create_table :reconciliation_case_reviews do |t|
      t.references :reconciliation_case, null: false, foreign_key: true, index: { name: 'idx_case_reviews_case' }
      t.references :user, null: false, foreign_key: true
      t.string :rule_key, null: false
      t.integer :rule_version, null: false
      t.string :case_key, null: false
      t.string :fingerprint, null: false
      t.string :decision, null: false
      t.text :comment
      t.json :history, null: false, default: []
      t.timestamps
      t.index [:rule_key, :rule_version, :case_key], unique: true, name: 'idx_case_reviews_identity'
      t.check_constraint "decision IN ('approved', 'deferred', 'rejected')", name: 'case_reviews_decision_check'
    end
  end
end
