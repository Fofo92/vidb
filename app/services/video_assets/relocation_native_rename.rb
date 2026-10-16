# frozen_string_literal: true

require 'fiddle'

module VideoAssets
  class RelocationNativeRename
    class Unsupported < StandardError; end

    def call(directory_fd, source, target)
      result = function.call(directory_fd, source, directory_fd, target, 1)
      raise SystemCallError.new('renameat2 RENAME_NOREPLACE', Fiddle.last_error) unless result.zero?
    rescue Fiddle::DLError
      raise Unsupported, 'renameat2 unavailable; no fallback was attempted'
    end

    private

    def function
      Fiddle::Function.new(Fiddle::Handle::DEFAULT['renameat2'],
                           [Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_INT,
                            Fiddle::TYPE_VOIDP, Fiddle::TYPE_INT], Fiddle::TYPE_INT)
    end
  end
end
