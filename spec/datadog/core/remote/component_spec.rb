# frozen_string_literal: true

require 'spec_helper'
require 'datadog/core/remote/component'

RSpec.describe Datadog::Core::Remote::Component, :integration do
  let(:settings) { Datadog::Core::Configuration::Settings.new }
  let(:agent_settings) { Datadog::Core::Configuration::AgentSettingsResolver.call(settings, logger: nil) }
  let(:capabilities) { Datadog::Core::Remote::Client::Capabilities.new(settings) }
  let(:component) { described_class.new(settings, capabilities, agent_settings) }

  around do |example|
    ClimateControl.modify('DD_REMOTE_CONFIGURATION_ENABLED' => nil) { example.run }
  end

  describe '.build' do
    subject(:build) { described_class.build(settings, agent_settings) }

    after { build.shutdown! if build }

    context 'remote disabled' do
      let(:remote) do
        mock = double('remote')
        expect(mock).to receive(:enabled).and_return(false)
        mock
      end

      before { expect(settings).to receive(:remote).and_return(remote) }

      it 'returns nil ' do
        is_expected.to be_nil
      end
    end

    context 'enabled' do
      let(:capabilities) { double('capabilities') }
      let(:component) { double('component', shutdown!: nil) }

      it 'initializes component' do
        expect(Datadog::Core::Remote::Client::Capabilities).to receive(:new).with(settings).and_return(capabilities)
        expect(described_class).to receive(:new).with(settings, capabilities, agent_settings).and_return(component)

        is_expected.to eq(component)
      end
    end
  end

  describe '#initialize' do
    subject(:component) { described_class.new(settings, capabilities, agent_settings) }

    after do
      component.shutdown!
    end

    context 'worker' do
      let(:worker) { component.instance_eval { @worker } }
      let(:client) { double }
      let(:transport_v7) { double }
      let(:negotiation) { double }

      before do
        expect(Datadog::Core::Remote::Transport::HTTP).to receive(:v7).and_return(transport_v7)
        expect(Datadog::Core::Remote::Client).to receive(:new).and_return(client)
        allow(Datadog::Core::Remote::Negotiation).to receive(:new).and_return(negotiation)

        expect(worker).to receive(:start).and_call_original
        expect(worker).to receive(:stop).and_call_original
      end

      context 'when client sync succeeds' do
        before do
          expect(negotiation).to receive(:endpoint?).and_return(true)
          expect(worker).to receive(:call).and_call_original
          expect(client).to receive(:sync).and_return(nil)
        end

        it 'does not log any error' do
          expect(Datadog.logger).to_not receive(:error)

          component.barrier(:once)
        end
      end

      context 'when client sync raises' do
        before do
          expect(negotiation).to receive(:endpoint?).and_return(true)
          expect(worker).to receive(:call).and_call_original
          expect(client).to receive(:sync).and_raise(exception, 'test')
          allow(Datadog.logger).to receive(:error).and_return(nil)
        end

        context 'StandardError' do
          let(:second_client) { double }
          let(:exception) { Class.new(StandardError) }

          it 'logs an error' do
            allow(Datadog::Core::Remote::Client).to receive(:new).and_return(client)

            expect(Datadog.logger).to receive(:error).and_return(nil)

            component.barrier(:once)
          end

          it 'catches exceptions' do
            allow(Datadog::Core::Remote::Client).to receive(:new).and_return(client)

            # if the error is uncaught it will crash the test, so a mere passing is good

            component.barrier(:once)
          end

          it 'creates a new client' do
            expect(Datadog::Core::Remote::Client).to receive(:new).and_return(second_client)

            expect(component.client.object_id).to eql(client.object_id)

            component.barrier(:once)

            expect(component.client.object_id).to eql(second_client.object_id)
          end

          it 'resets the negotiation object' do
            allow(Datadog::Core::Remote::Client).to receive(:new).and_return(second_client)

            component.barrier(:once)

            expect(Datadog::Core::Remote::Negotiation).to have_received(:new).twice
          end
        end

        context 'Client::SyncError' do
          let(:exception) { Class.new(Datadog::Core::Remote::Client::SyncError) }

          it 'logs an error' do
            allow(Datadog::Core::Remote::Client).to receive(:new).and_return(client)

            expect(Datadog.logger).to receive(:error).and_return(nil)

            component.barrier(:once)
          end

          it 'catches exceptions' do
            allow(Datadog::Core::Remote::Client).to receive(:new).and_return(client)

            # if the error is uncaught it will crash the test, so a mere passing is good

            component.barrier(:once)
          end

          it 'does not creates a new client' do
            expect(Datadog::Core::Remote::Client).to_not receive(:new)

            expect(component.client.object_id).to eql(client.object_id)

            component.barrier(:once)

            expect(component.client.object_id).to eql(client.object_id)
          end
        end
      end
    end
  end

  describe '#start' do
    subject(:start) { component.start }
    after { component.shutdown! }

    it { expect { start }.to change { component.started? }.from(false).to(true) }

    it 'does not wait for first sync' do
      expect(component.client).to_not receive(:sync)
      start
    end

    context 'when already started' do
      before { component.start }

      it { expect { start }.to_not change { component.started? }.from(true) }
    end
  end

  describe '#started?' do
    subject(:started?) { component.started? }

    context 'before start' do
      it { is_expected.to eq(false) }
    end

    context 'after start' do
      before { component.start }
      after { component.shutdown! }

      it { is_expected.to eq(true) }

      context 'then shutdown' do
        before { component.shutdown! }

        it { is_expected.to eq(false) }
      end
    end
  end
end
