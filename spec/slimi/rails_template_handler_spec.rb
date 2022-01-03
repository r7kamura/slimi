# frozen_string_literal: true

require 'action_view'

RSpec.describe Slimi::RailsTemplateHandler do
  describe '#call' do
    subject do
      handler.call(template)
    end

    let(:format) do
      :html
    end

    let(:handler) do
      described_class.new
    end

    let(:identifier) do
      'dummy.slim'
    end

    let(:source) do
      <<~'SLIM'
        | a
      SLIM
    end

    let(:template) do
      ActionView::Template.new(
        source,
        identifier,
        handler,
        format: format,
        locals: {}
      )
    end

    let(:output_buffer) do
      nil
    end

    context 'with valid condition' do
      it 'returns Ruby code that returns expected String' do
        result = eval(subject, binding)
        expect(result).to eq('a')
      end
    end

    context 'with annotate_rendered_view_with_filenames and :html format' do
      before do
        allow(ActionView::Base).to receive(:annotate_rendered_view_with_filenames).and_return(true)
      end

      it 'returns Ruby code that returns expected String' do
        result = eval(subject, binding)
        expect(result).to eq(<<~HTML)
          <!-- BEGIN dummy.slim -->
          a<!-- END dummy.slim -->
        HTML
      end
    end

    context 'with annotate_rendered_view_with_filenames and :text format' do
      before do
        allow(ActionView::Base).to receive(:annotate_rendered_view_with_filenames).and_return(true)
      end

      let(:format) do
        :text
      end

      it 'returns Ruby code that returns expected String' do
        result = eval(subject)
        expect(result).to eq('a')
      end
    end
  end
end
