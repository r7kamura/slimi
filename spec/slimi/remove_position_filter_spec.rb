# frozen_string_literal: true

RSpec.describe Slimi::RemovePositionFilter do
  describe '#call' do
    subject do
      filter.call(node)
    end

    let(:filter) do
      described_class.new
    end

    context 'with :slimi :position node' do
      let(:node) do
        [:slimi, :position, 0, 1, inner_node]
      end

      let(:inner_node) do
        [:slim, :interpolate, '1']
      end

      it 'converts :slimi :position node into inner :slim node' do
        is_expected.to eq(inner_node)
      end
    end
  end
end
