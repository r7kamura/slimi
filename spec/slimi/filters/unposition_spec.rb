# frozen_string_literal: true

RSpec.describe Slimi::Filters::Unposition do
  describe '#call' do
    subject do
      filter.call(node)
    end

    let(:filter) do
      described_class.new
    end

    context 'with :slimi :position node' do
      let(:node) do
        [:multi, [:slimi, :position, 0, 1, [:slim, :interpolate, '1']]]
      end

      it 'converts :slimi :position node into inner :slim node' do
        is_expected.to eq(
          [:multi, [:slim, :interpolate, '1']]
        )
      end
    end

    context 'with complex node' do
      let(:node) do
        [:multi, [:html, :tag, 'p', %i[html attrs], [:slimi, :position, 1, 3, [:slim, :text, :inline, [:multi, [:slimi, :position, 3, 3, [:slim, :interpolate, ' a']]]]]], [:newline]]
      end

      it 'converts :slimi :position node into inner :slim node' do
        is_expected.to eq(
          [:multi, [:html, :tag, 'p', %i[html attrs], [:slim, :text, :inline, [:multi, [:slim, :interpolate, ' a']]]], [:newline]]
        )
      end
    end
  end
end
