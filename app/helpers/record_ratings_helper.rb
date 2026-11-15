# frozen_string_literal: true

module RecordRatingsHelper
  def current_record_rating(record)
    record.ratings.to_a.find { |rating| rating.user_id == current_user.id }
  end

  def record_rating_label(record)
    value = current_record_rating(record)&.value
    value ? "Avis : #{value}/5" : 'Sans avis'
  end

  def record_rating_filter_path(value)
    query = request.query_parameters.deep_dup
    filters = query.fetch('filters', {}).dup
    filters['rating'] = value
    filters.delete('rating') if value.nil?
    query['filters'] = filters
    query.delete('page')
    records_path(query)
  end

  def record_rating_filter_options
    [['Tous', nil], ['Sans avis', 'unrated']] + (1..5).map { |value| ['★' * value, value.to_s] }
  end
end
