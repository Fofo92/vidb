# frozen_string_literal: true

require 'json'

raise 'Environnement vidb_production requis' unless
  Rails.env.production? && ActiveRecord::Base.connection_db_config.database == 'vidb_production'

if ARGV.empty?
  result = ActiveRecord::Base.transaction(isolation: :repeatable_read) do
    ActiveRecord::Base.connection.execute('SET TRANSACTION READ ONLY')
    VideoAssets::ConditionConventionPlan.new.call
  end
elsif ARGV.size == 2 && ARGV.first == '--apply'
  if ARGV.last == '-'
    document = $stdin.read(64.megabytes + 1)
  else
    path = Pathname.new(ARGV.last)
    raise 'Plan trop volumineux' if path.size > 64.megabytes

    document = path.read
  end
  raise 'Plan trop volumineux' if document.bytesize > 64.megabytes

  result = VideoAssets::ConditionConventionApply.new.call(JSON.parse(document))
else
  raise 'Usage : aperçu sans argument, ou --apply /chemin/plan.json'
end

puts JSON.pretty_generate(result)
