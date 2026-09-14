class CreateTvGuideImports < ActiveRecord::Migration[8.1]
  def change
    create_guide_imports
    add_byte_size_constraint
    add_sha256_constraint
    add_status_constraint
    add_successful_import_index
  end

  private

  def create_guide_imports
    create_table :tv_guide_imports do |t|
      t.references :guide_source, null: false,
                                  foreign_key: { to_table: :tv_guide_sources }
      t.string :document_sha256, null: false
      t.bigint :document_byte_size, null: false
      t.string :status, default: "running", null: false
      t.timestamps
    end
  end

  def add_byte_size_constraint
    add_check_constraint(
      :tv_guide_imports,
      "document_byte_size >= 0",
      name: "tv_guide_imports_byte_size_check"
    )
  end

  def add_sha256_constraint
    add_check_constraint(
      :tv_guide_imports,
      "document_sha256 ~ '^[0-9A-Fa-f]{64}$'",
      name: "tv_guide_imports_sha256_check"
    )
  end

  def add_status_constraint
    add_check_constraint(
      :tv_guide_imports,
      "status IN ('running', 'succeeded', 'failed')",
      name: "tv_guide_imports_status_check"
    )
  end

  def add_successful_import_index
    add_index(
      :tv_guide_imports,
      %i[guide_source_id document_sha256],
      unique: true,
      where: "status = 'succeeded'",
      name: "index_unique_successful_tv_guide_import"
    )
  end
end
