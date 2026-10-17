# frozen_string_literal: true

module RecordGenreProvenance
  extend ActiveSupport::Concern

  module AssociationMutations
    def clear
      with_genre_bulk_protection { super }
    end

    def delete_all(...)
      with_genre_bulk_protection { super }
    end

    private

    def with_genre_bulk_protection
      owner = proxy_association.owner
      owner.class.transaction do
        owner.capture_genres_before_change(nil)
        result = yield
        owner.protect_cleared_genres
        result
      end
    end
  end

  def with_reviewed_genre_assignment
    previous = @reviewed_genre_assignment
    @reviewed_genre_assignment = true
    yield
  ensure
    @reviewed_genre_assignment = previous
  end

  def capture_genres_before_change(_gender)
    return if @reviewed_genre_assignment

    @genres_before_change = persisted_genre_names
  end

  def protect_added_genre(gender)
    protect_genre_change(gender, added: true)
  end

  def protect_removed_genre(gender)
    protect_genre_change(gender, added: false)
  end

  def protect_cleared_genres
    return if @reviewed_genre_assignment || @genres_before_change == persisted_genre_names

    new_record? ? protect_new_record_genres([]) : protect_persisted_record_genres
  end

  private

  def persisted_genre_names
    return association(:genders).target.map(&:name).uniq.sort if new_record?

    genders.scope.distinct.pluck(:name).sort
  end

  def protect_genre_change(gender, added:)
    return if @reviewed_genre_assignment

    names = changed_genre_names(gender, added: added)
    return if names == @genres_before_change

    new_record? ? protect_new_record_genres(names) : protect_persisted_record_genres
  end

  def changed_genre_names(gender, added:)
    return persisted_genre_names if persisted?

    names = @genres_before_change || []
    (added ? names + [gender.name] : names - [gender.name]).uniq.sort
  end

  def protect_new_record_genres(names)
    self.genre_provenance = manual_genre_receipt(genre_provenance, names)
  end

  def protect_persisted_record_genres
    # Lock the database row without reloading/discarding pending form attributes.
    previous = self.class.where(id: id).lock.pick(:genre_provenance)
    names = persisted_genre_names
    update_columns(genre_provenance: manual_genre_receipt(previous, names))
  end

  def manual_genre_receipt(previous, names)
    previous ||= {}
    history = Array(previous['history'])
    history += [previous.except('history')] unless previous.empty?
    { 'origin' => 'manual_or_untracked', 'protected' => true, 'genres' => names,
      'previous_genres' => @genres_before_change, 'recorded_at' => Time.current.iso8601,
      'history' => history }
  end
end
