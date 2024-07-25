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
        [:multi, [:slimi, :text, :verbatim, [:multi, [:slimi, :interpolate, 2, 6, '#{a}']]], [:newline]]
      end

      it 'converts it into :multi nodes' do
        is_expected.to eq(
          [:multi, [:slimi, :text, :verbatim, [:multi, [:multi, [:slimi, :position, 4, 5, [:slimi, :output, false, 'a', [:multi]]]]]], [:newline]]
        )
      end
    end

    context 'with non-escaped :slimi :interpolate node' do
      let(:node) do
        [:multi, [:slimi, :text, :verbatim, [:multi, [:slimi, :interpolate, 2, 8, '#{{a}}']]], [:newline]]
      end

      it 'converts it into :multi nodes' do
        is_expected.to eq(
          [:multi, [:slimi, :text, :verbatim, [:multi, [:multi, [:slimi, :position, 5, 6, [:slimi, :output, true, 'a', [:multi]]]]]], [:newline]]
        )
      end
    end
  end
end
