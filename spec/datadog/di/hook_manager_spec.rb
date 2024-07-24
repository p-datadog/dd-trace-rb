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
    end
  end

  let(:settings) do
    double('settings').tap do |settings|
      allow(settings).to receive(:internal_dynamic_instrumentation).and_return(di_settings)
    end
  end

  let(:di_settings) do
    double('di settings').tap do |settings|
      allow(settings).to receive(:enabled).and_return(true)
    end
  end

  let(:manager) do
    RSpec::Mocks.with_temporary_scope do
      # TODO consider splitting HookManager into a class that hooks and
      # a class that maintains registry of probes
      expect(TracePoint).to receive(:trace).with(:end).and_return(definition_trace_point)

      described_class.new(settings)
    end.tap do |manager|
      # Since we are skipping definition trace point setup, we also
      # need to skip its teardown otherwise .close would try to disable
      # the double that is no longer in scope.
      allow(manager).to receive(:close).and_return(nil)
    end
  end

  shared_context 'DI component referencing hook manager under test' do

    let(:component) do
      double('DI component').tap do |component|
        allow(component).to receive(:hook_manager).and_return(manager)
      end
    end

    before do
      # TODO think about how the hook manager would make it into
      # the DI component in unit tests/partial initialization scenarios
      allow(Datadog::DI).to receive(:component).and_return(component)
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
    include_context 'DI component referencing hook manager under test'

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
      it 'raises DITargetNotDefined' do
        expect do
          manager.hook_method(:NonExistent, :non_existent) do |payload|
          end
        end.to raise_error(Datadog::DI::Error::DITargetNotDefined)
      end
    end
  end

  describe '.hook_method_when_defined' do
    let(:manager) do
      described_class.new(settings)
    end

    include_context 'DI component referencing hook manager under test'

    context 'when class does not exist' do
      it 'returns false' do
        expect(manager.hook_method_when_defined(:NonExistent, :non_existent) do |payload|
        end).to be false
      end
    end

    context 'when class is defined later' do
      it 'returns false, then instruments after definition' do
        invoked = false

        expect(manager.hook_method_when_defined(:HookManagerTestLateDefinition, :test_method) do |tp|
          invoked = true
        end).to be false

        expect(manager.send(:pending_methods)[[:HookManagerTestLateDefinition, :test_method]]).to be_a(Proc)
        expect(manager.send(:instrumented_methods)[[:HookManagerTestLateDefinition, :test_method]]).to be nil

        class HookManagerTestLateDefinition
          def test_method
            42
          end
        end

        # Method should now be hooked, and no longer pending
        expect(manager.send(:pending_methods)[[:HookManagerTestLateDefinition, :test_method]]).to be nil
        expect(manager.send(:instrumented_methods)[[:HookManagerTestLateDefinition, :test_method]]).to be_a(Integer)

        expect(HookManagerTestLateDefinition.new.test_method).to eq 42

        expect(invoked).to be true
      end
    end
  end

  describe '.hook_line_when_defined' do
    let(:manager) do
      described_class.new(settings)
    end

    include_context 'DI component referencing hook manager under test'

    context 'when file is not loaded' do
      context 'when code tracking is available' do
        let(:code_tracker) do
          double('code tracker').tap do |code_tracker|
            allow(code_tracker).to receive(:[])
          end
        end

        before do
          expect(Datadog::DI).to receive(:code_tracking_active?).and_return(true)
          expect(Datadog::DI).to receive(:code_tracker).and_return(code_tracker)
          # TODO test with untargeted trace points enabled?
          # behavior is the same.
          expect(di_settings).to receive(:untargeted_trace_points).and_return(false)
        end

        it 'returns false' do
          expect(manager.hook_line_when_defined('nonexistent', 1) do |payload|
          end).to be false
        end

        xit 'does not install instrumentation' do
          # TODO
        end
      end

      context 'when code tracking is not available' do
        it 'returns true' do
          expect(manager.hook_line_when_defined('nonexistent', 1) do |payload|
          end).to be true
        end

        xit 'installs instrumentation' do
          # TODO
        end
      end
    end

    context 'when file is loaded later' do
      context 'when code tracking is available' do
        before do
          Datadog::DI.activate_tracking!
        end

        after do
          Datadog::DI.deactivate_tracking!
        end

        before do
          expect(Datadog::DI.component.hook_manager).to be manager
          # TODO test with untargeted trace points enabled?
          # behavior is the same.
          expect(di_settings).to receive(:untargeted_trace_points).and_return(false)
        end

        it 'returns false, then instruments after definition' do
          invoked = false

          expect(manager.hook_line_when_defined('hook_line_delayed_ct.rb', 3) do |tp|
            invoked = true
          end).to be false

          expect(manager.send(:pending_lines)[['hook_line_delayed_ct.rb', 3]]).to be_a(Proc)
          expect(manager.send(:instrumented_lines)[3]).to be nil

          require_relative 'hook_line_delayed_ct'

          # Method should now be hooked, and no longer pending
          expect(manager.send(:pending_lines)[['hook_line_delayed_ct.rb', 3]]).to be nil
          expect(manager.send(:instrumented_lines)[3]['hook_line_delayed_ct.rb']).to be_a(Proc)

          expect(HookLineDelayedCtTestClass.new.test_method).to eq 42

          expect(invoked).to be true
        end
      end

      context 'when code tracking is not available' do

        context 'untargeted trace points disabled' do
          let(:di_settings) do
            double('di settings').tap do |settings|
              allow(settings).to receive(:enabled).and_return(true)
              allow(settings).to receive(:propagate_all_exceptions).and_return(false)
            end
          end

          it 'does not instrument' do
            invoked = false

            expect(manager.hook_line_when_defined('hook_line_delayed.rb', 3) do |tp|
              invoked = true
            end).to be false

            expect(manager.send(:pending_lines)[['hook_line_delayed.rb', 3]]).to be nil
            expect(manager.send(:instrumented_lines)[3]).to be nil

            require_relative 'hook_line_delayed'

            expect(manager.send(:pending_lines)[['hook_line_delayed.rb', 3]]).to be nil
            expect(manager.send(:instrumented_lines)[3]).to be nil

            expect(HookManagerTestLateDefinition.new.test_method).to eq 42

            expect(invoked).to be false

            # Repeat hook call to verify that the test is written correctly.

            expect(manager.hook_line_when_defined('hook_line_delayed.rb', 3) do |tp|
              invoked = true
            end).to be true

            expect(HookManagerTestLateDefinition.new.test_method).to eq 42

            expect(invoked).to be true
          end
        end

        context 'untargeted trace points enabled' do
          it 'instruments immediately' do
            invoked = false

            expect(manager.hook_line_when_defined('hook_line_delayed.rb', 3) do |tp|
              invoked = true
            end).to be true

            expect(manager.send(:pending_lines)[['hook_line_delayed.rb', 3]]).to be nil
            expect(manager.send(:instrumented_lines)[['hook_line_delayed.rb', 3]]).to be_a(Integer)

            require_relative 'hook_line_delayed'

            # Method should now be hooked, and no longer pending
            expect(manager.send(:pending_lines)[['hook_line_delayed.rb', 3]]).to be nil
            expect(manager.send(:instrumented_lines)[['hook_line_delayed.rb', 3]]).to be_a(Integer)

            expect(HookManagerTestLateDefinition.new.test_method).to eq 42

            expect(invoked).to be true
          end
        end
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
        expect(Datadog::DI.code_tracker.send(:registry)['hook_line_targeted.rb']).to be_a(RubyVM::InstructionSequence)
      end

      it 'targets the trace point' do
        # TODO the path key could be different in the future
        target = Datadog::DI.code_tracker.send(:registry)['hook_line_targeted.rb']
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
