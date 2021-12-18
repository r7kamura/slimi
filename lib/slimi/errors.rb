# frozen_string_literal: true

module Slimi
  module Errors
    class BaseError < StandardError
    end

    class ParserError < BaseError
    end

    class LineEndingNotFoundError < ParserError
    end

    class MalformedIndentationError < ParserError
    end

    class UnexpectedEosError < ParserError
    end

    class UnexpectedIndentationError < ParserError
    end

    class UnexpectedTextAfterClosedTagError < ParserError
    end

    class UnknownLineIndicator < ParserError
    end
  end
end
