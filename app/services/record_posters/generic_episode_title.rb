# frozen_string_literal: true

module RecordPosters
  # Recognize labels, never arbitrary titles beginning with the word Episode.
  class GenericEpisodeTitle
    SMALL = %w[zero one two three four five six seven eight nine ten eleven twelve
               thirteen fourteen fifteen sixteen seventeen eighteen nineteen].freeze
    TENS = %w[zero ten twenty thirty forty fifty sixty seventy eighty ninety].freeze

    def self.number(title)
      key = title.to_s.unicode_normalize(:nfkd).downcase.gsub(/[^\p{Alnum}]/, '')
      match = key.match(/\Aepisode([a-z]+|\d+)\z/) || key.match(/\Ateil(\d+)\z/)
      return unless match

      suffix = match[1]
      suffix.match?(/\A\d+\z/) ? suffix.to_i : word_numbers[suffix]
    end

    def self.word_numbers
      @word_numbers ||= (0..99).to_h { |number| [word(number), number] }.freeze
    end
    private_class_method :word_numbers

    def self.word(number)
      return SMALL.fetch(number) if number < SMALL.size

      tens = TENS.fetch(number / 10)
      number.modulo(10).zero? ? tens : "#{tens}#{SMALL.fetch(number % 10)}"
    end
    private_class_method :word
  end
end
