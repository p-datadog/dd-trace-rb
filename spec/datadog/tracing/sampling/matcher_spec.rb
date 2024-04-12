require 'spec_helper'

require 'datadog/tracing/sampling/matcher'

RSpec.describe Datadog::Tracing::Sampling::SimpleMatcher do
  let(:trace_op) do
    Datadog::Tracing::TraceOperation.new(name: trace_name, service: trace_service, resource: trace_resource)
  end
  let(:trace_name) { 'operation.name' }
  let(:trace_service) { 'test-service' }
  let(:trace_resource) { 'test-resource' }

  describe '#match?' do
    subject(:match?) { rule.match?(trace_op) }

    context 'with a name matcher' do
      let(:rule) { described_class.new(name: name) }

      context 'with a regexp' do
        context 'matching' do
          let(:name) { /.*/ }

          it { is_expected.to eq(true) }
        end

        context 'not matching' do
          let(:name) { /^$/ }

          it { is_expected.to eq(false) }
        end
      end

      context 'with a string' do
        context 'matching' do
          let(:name) { trace_name.to_s }

          it { is_expected.to eq(true) }
        end

        context 'not matching' do
          let(:name) { '' }

          it { is_expected.to eq(false) }
        end
      end

      context 'with a proc' do
        context 'matching' do
          let(:name) { ->(n) { n == trace_name } }

          it { is_expected.to eq(true) }
        end

        context 'not matching' do
          let(:name) { ->(_n) { false } }

          it { is_expected.to eq(false) }
        end
      end
    end

    context 'with a service matcher' do
      let(:rule) { described_class.new(service: service) }

      context 'when trace service name is present' do
        let(:trace_service) { 'service-1' }

        context 'with a regexp' do
          context 'matching' do
            let(:service) { /.*/ }

            it { is_expected.to eq(true) }
          end

          context 'not matching' do
            let(:service) { /^$/ }

            it { is_expected.to eq(false) }
          end
        end

        context 'with a string' do
          context 'matching' do
            let(:service) { trace_service.to_s }

            it { is_expected.to eq(true) }
          end

          context 'not matching' do
            let(:service) { '' }

            it { is_expected.to eq(false) }
          end
        end

        context 'with a proc' do
          context 'matching' do
            let(:service) { ->(n) { n == trace_service } }

            it { is_expected.to eq(true) }
          end

          context 'not matching' do
            let(:service) { ->(_n) { false } }

            it { is_expected.to eq(false) }
          end
        end
      end

      context 'when trace service is not present' do
        let(:trace_service) { nil }
        let(:service) { /.*/ }

        it { is_expected.to eq(false) }
      end
    end

    context 'with a resource matcher' do
      let(:rule) { described_class.new(resource: resource) }

      context 'when trace resource is present' do
        let(:trace_resource) { 'resource-1' }

        context 'with a regexp' do
          context 'matching' do
            let(:resource) { /resource-.*/ }

            it { is_expected.to eq(true) }
          end

          context 'not matching' do
            let(:resource) { /name-.*/ }

            it { is_expected.to eq(false) }
          end
        end

        context 'with a string' do
          context 'matching' do
            let(:resource) { 'resource-1' }

            it { is_expected.to eq(true) }
          end

          context 'not matching' do
            let(:resource) { 'not-resource' }

            it { is_expected.to eq(false) }
          end
        end

        context 'with a proc' do
          context 'matching' do
            let(:resource) { ->(n) { n == 'resource-1' } }

            it { is_expected.to eq(true) }
          end

          context 'not matching' do
            let(:resource) { ->(_n) { false } }

            it { is_expected.to eq(false) }
          end
        end
      end

      context 'when trace resource is not present' do
        let(:trace_resource) { nil }
        let(:resource) { /.*/ }

        it { is_expected.to eq(false) }
      end
    end

    context 'with name, service, resource matchers' do
      let(:rule) { described_class.new(name: name, service: service, resource: resource) }

      let(:name) { /.*/ }
      let(:service) { /.*/ }
      let(:resource) { /.*/ }

      context 'when trace service name is present' do
        let(:trace_service) { 'service-1' }

        it { is_expected.to eq(true) }
      end

      context 'when trace service is not present' do
        let(:trace_service) { nil }

        it { is_expected.to eq(false) }
      end
    end
  end
end

RSpec.describe Datadog::Tracing::Sampling::ProcMatcher do
  let(:trace_op) { Datadog::Tracing::SpanOperation.new(trace_name, service: trace_service) }
  let(:trace_name) { 'operation.name' }
  let(:trace_service) { nil }

  describe '#match?' do
    subject(:match?) { rule.match?(trace_op) }

    let(:rule) { described_class.new(&block) }

    context 'with matching block' do
      let(:block) { ->(name, service) { name == trace_name && service == trace_service } }

      it { is_expected.to eq(true) }
    end

    context 'with mismatching block' do
      let(:block) { ->(_name, _service) { false } }

      it { is_expected.to eq(false) }
    end
  end
end
