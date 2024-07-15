require 'datadog/di/hook_manager'
require_relative 'hook_line'

class HookTestClass
  def hook_test_method
    42
  end

  def hook_test_method_with_arg(arg)
    arg
  end

  def hook_test_method_with_kwarg(kwarg:)
    kwarg
  end
end

RSpec.describe Datadog::DI::HookManager do
  let(:observed_calls) { [] }

  let(:definition_trace_point) do
    double('definition trace point').tap do |tp|
      expect(tp).to receive(:enable)
    end
  end

  let(:manager) do
    RSpec::Mocks.with_temporary_scope do
      # TODO consider splitting HookManager into a class that hooks and
      # a class that maintains registry of probes
      expect(TracePoint).to receive(:new).with(:end).and_return(definition_trace_point)

      described_class.new
    end.tap do |manager|
      # Since we are skipping definition trace point setup, we also
      # need to skip its teardown otherwise .close would try to disable
      # the double that is no longer in scope.
      allow(manager).to receive(:close).and_return(nil)
    end
  end

  after do
    manager.clear_hooks
    #manager.close
  end

  let(:call_keys) do
    [:callers, :duration, :rv]
  end

  describe '.hook_method' do
    context 'no args' do
      it 'invokes callback' do
        manager.hook_method(:HookTestClass, :hook_test_method) do |payload|
          observed_calls << payload
        end

        expect(HookTestClass.new.hook_test_method).to eq 42

        expect(observed_calls.length).to eq 1
        expect(observed_calls.first.keys.sort).to eq call_keys
        expect(observed_calls.first[:rv]).to eq 42
        expect(observed_calls.first[:duration]).to be_a(Float)
      end
    end

    context 'positional args' do
      it 'invokes callback' do
        manager.hook_method(:HookTestClass, :hook_test_method_with_arg) do |payload|
          observed_calls << payload
        end

        expect(HookTestClass.new.hook_test_method_with_arg(2)).to eq 2

        expect(observed_calls.length).to eq 1
        expect(observed_calls.first.keys.sort).to eq call_keys
        expect(observed_calls.first[:rv]).to eq 2
        expect(observed_calls.first[:duration]).to be_a(Float)
      end
    end

    context 'when hooked twice' do
      it 'only invokes callback once' do
        manager.hook_method(:HookTestClass, :hook_test_method) do |payload|
          observed_calls << payload
        end

        manager.hook_method(:HookTestClass, :hook_test_method) do |payload|
          observed_calls << payload
        end

        expect(HookTestClass.new.hook_test_method).to eq 42

        expect(observed_calls.length).to eq 1
        expect(observed_calls.first.keys.sort).to eq call_keys
        expect(observed_calls.first[:rv]).to eq 42
        expect(observed_calls.first[:duration]).to be_a(Float)
      end
    end

    context 'when class does not exist' do
      it 'raises DITargetNotDefined:' do
        expect do
          manager.hook_method(:NonExistent, :non_existent) do |payload|
          end
        end.to raise_error(Datadog::DI::Error::DITargetNotDefined)
      end
    end
  end

  describe '.hook_line' do
    context 'method definition line' do
      it 'does not invoke callback' do

        expect_any_instance_of(TracePoint).to receive(:enable).with(target: nil).and_call_original

        manager.hook_line('hook_line.rb', 2) do |payload|
          observed_calls << payload
        end

        HookLineTestClass.new.test_method

        expect(observed_calls).to be_empty
      end
    end

    context 'line inside of method' do
      it 'invokes callback' do

        expect_any_instance_of(TracePoint).to receive(:enable).with(target: nil).and_call_original

        manager.hook_line('hook_line.rb', 3) do |payload|
          observed_calls << payload
        end

        HookLineTestClass.new.test_method

        expect(observed_calls.length).to eq 1
        expect(observed_calls.first).to be_a(TracePoint)
      end
    end

    context 'when hooked twice' do
      xit 'invokes callback only once' do
        manager.hook_line('hook_line.rb', 3) do |payload|
          observed_calls << payload
        end

        manager.hook_line('hook_line.rb', 3) do |payload|
          observed_calls << payload
        end

        HookLineTestClass.new.test_method

        expect(observed_calls.length).to eq 1
        expect(observed_calls.first).to be_a(TracePoint)
      end
    end

    context 'when code tracking is available' do
      before do
        Datadog::DI.activate_tracking!
        require_relative 'hook_line_targeted'

        # TODO the path key could be different in the future
        expect(Datadog::DI.code_tracker.send(:file_registry)['hook_line_targeted.rb']).to be_a(RubyVM::InstructionSequence)
      end

      it 'targets the trace point' do
        # TODO the path key could be different in the future
        target = Datadog::DI.code_tracker.send(:file_registry)['hook_line_targeted.rb']
        expect(target).to be_a(RubyVM::InstructionSequence)

        expect_any_instance_of(TracePoint).to receive(:enable).with(target: target).and_call_original

        manager.hook_line('hook_line_targeted.rb', 3) do |payload|
          observed_calls << payload
        end

        HookLineTargetedTestClass.new.test_method

        expect(observed_calls.length).to eq 1
        expect(observed_calls.first).to be_a(TracePoint)
      end
    end
  end
end
