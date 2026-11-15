# frozen_string_literal: true

module RecordGenreIconsHelper
  GENRE_ICONS = {
    'policier' => 'magnifying-glass', 'action' => 'bolt', 'aventure' => 'compass',
    'science-fiction' => 'rocket', 'fantastique' => 'wand-magic-sparkles', 'horreur' => 'ghost',
    'guerre' => 'helmet-un', 'western' => 'hat-cowboy', 'animation' => 'palette',
    'documentaire' => 'video', 'musique' => 'music', 'comedie-musicale' => 'music',
    'romance' => 'heart', 'sport' => 'futbol', 'comedie-drame' => 'masks-theater'
  }.freeze

  GENRE_DRAWINGS = {
    'fantasy' => 'magic', 'fantaisie' => 'magic', 'fantastique' => 'magic',
    'histoire' => 'history', 'historique' => 'history', 'espionnage' => 'spy',
    'peplum' => 'roman', 'policier' => 'police', 'theatre' => 'theatre',
    'super-heros' => 'superhero', 'superheros' => 'superhero',
    'thriller' => 'thriller', 'biopic' => 'biopic', 'biographie' => 'biopic'
  }.freeze

  def record_index_genres(genders)
    names = genders.first(2).map(&:name).uniq
    return '—' if names.empty?

    display_names = theatre_genre_pair?(names) ? ['Comédie, Drame'] : names
    symbols = display_names.map { |name| record_genre_symbol(name) }
    tag.span(safe_join(symbols, ' '), class: 'record-genre-icons', title: names.join(', '),
                                      role: 'img', aria: { label: names.join(', ') })
  end

  def record_genre_symbol(name)
    key = name.parameterize
    symbol = GENRE_DRAWINGS[key]
    return render('records/genre_symbol', symbol: symbol) if symbol

    return render('records/genre_mask', smile: key == 'comedie') if %w[comedie drame].include?(key)

    icon = GENRE_ICONS[key]
    icon ? tag.i(class: "fa-solid fa-#{icon}", aria: { hidden: true }) : tag.span(name)
  end

  def record_genre_button_symbol(name)
    return record_genre_symbol(name) if record_genre_symbol_known?(name)

    tag.i(class: 'fa-solid fa-tag', aria: { hidden: true })
  end

  def record_genre_symbol_known?(name)
    key = name.parameterize
    %w[comedie drame].include?(key) || GENRE_DRAWINGS.key?(key) || GENRE_ICONS.key?(key)
  end

  def record_genre_filter_path(gender_id)
    query = request.query_parameters.deep_dup
    filters = query.fetch('filters', {}).dup
    filters['gender_id'] = gender_id
    filters.delete('gender_id') if gender_id.nil?
    query['filters'] = filters
    query.delete('page')
    records_path(query)
  end

  private

  def theatre_genre_pair?(names)
    names.map(&:parameterize).sort == %w[comedie drame]
  end
end
