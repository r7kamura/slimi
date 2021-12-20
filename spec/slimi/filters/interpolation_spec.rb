# frozen_string_literal: true

RSpec.describe Slimi::Filters::Interpolation do
  describe '#call' do
    subject do
      filter.call(node)
    end

    let(:filter) do
      described_class.new
    end

    context 'with :slimi :interpolate node' do
      let(:node) do
        [:multi, [:slim, :text, :verbatim, [:multi, [:slimi, :interpolate, 2, 6, '#{a}']]], [:newline]]
      end

      it 'converts it into :multi nodes' do
        is_expected.to eq(
          [:multi, [:slim, :text, :verbatim, [:multi, [:multi, [:slimi, :position, 4, 5, [:slim, :output, false, 'a', [:multi]]]]]], [:newline]]
        )
      end
    end
  end
end
