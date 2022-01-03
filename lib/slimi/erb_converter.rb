# frozen_string_literal: true

module Slimi
  # Convert Slim into ERB.
  class ErbConverter < Engine
    replace :StaticMerger, ::Temple::Filters::CodeMerger
    replace :Generator, Temple::Generators::ERB
  end
end
