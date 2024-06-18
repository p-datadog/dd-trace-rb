require 'datadog/di/hook'
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

RSpec.describe Datadog::DI::Hook do
  let(:observed_calls) { [] }

  after do
    described_class.clear_hooks
  end

  let(:call_keys) do
    [:callers, :duration, :rv]
  end

  describe '.hook_method' do
    context 'no args' do
      it 'invokes callback' do
        described_class.hook_method(:HookTestClass, :hook_test_method) do |payload|
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
        described_class.hook_method(:HookTestClass, :hook_test_method_with_arg) do |payload|
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
        described_class.hook_method(:HookTestClass, :hook_test_method) do |payload|
          observed_calls << payload
        end

        described_class.hook_method(:HookTestClass, :hook_test_method) do |payload|
          observed_calls << payload
        end

        expect(HookTestClass.new.hook_test_method).to eq 42

        expect(observed_calls.length).to eq 1
        expect(observed_calls.first.keys.sort).to eq call_keys
        expect(observed_calls.first[:rv]).to eq 42
        expect(observed_calls.first[:duration]).to be_a(Float)
      end
    end
  end

  describe '.hook_line' do
    context 'method definition line' do
      it 'does not invoke callback' do
        described_class.hook_line('hook_line.rb', 2) do |payload|
          observed_calls << payload
        end

        HookLineTestClass.new.test_method

        expect(observed_calls).to be_empty
      end
    end

    context 'line inside of method' do
      it 'invokes callback' do
        described_class.hook_line('hook_line.rb', 3) do |payload|
          observed_calls << payload
        end

        HookLineTestClass.new.test_method

        expect(observed_calls.length).to eq 1
        expect(observed_calls.first).to be_a(TracePoint)
      end
    end

    context 'when hooked twice' do
      xit 'invokes callback only once' do
        described_class.hook_line('hook_line.rb', 3) do |payload|
          observed_calls << payload
        end

        described_class.hook_line('hook_line.rb', 3) do |payload|
          observed_calls << payload
        end

        HookLineTestClass.new.test_method

        expect(observed_calls.length).to eq 1
        expect(observed_calls.first).to be_a(TracePoint)
      end
    end
  end
end
