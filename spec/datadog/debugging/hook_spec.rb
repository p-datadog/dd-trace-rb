#require 'spec_helper'
require 'datadog/debugger/hook'
require_relative 'hook_line'

Warning.ignore(/void context/, /spec/)
RSpec.configure do |config|
  config.expose_dsl_globally = true
  config.expect_with :rspec do |expectations|
    expectations.syntax = [:should, :expect]
  end
end

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

describe Datadog::Debugging::Hook do
  let(:observed_calls) { [] }

  after do
    described_class.clear_hooks
  end

  describe '.hook_method' do
    context 'no args' do
      it 'invokes callback' do
        described_class.hook_method(:HookTestClass, :hook_test_method) do |payload|
          observed_calls << payload
        end

        HookTestClass.new.hook_test_method.should == 42

        observed_calls.length.should == 1
        observed_calls.first.should == {rv: 42}
      end
    end

    context 'positional args' do
      it 'invokes callback' do
        described_class.hook_method(:HookTestClass, :hook_test_method_with_arg) do |payload|
          observed_calls << payload
        end

        HookTestClass.new.hook_test_method_with_arg(2).should == 2

        observed_calls.length.should == 1
        observed_calls.first.should == {rv: 2}
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

        HookTestClass.new.hook_test_method.should == 42

        observed_calls.length.should == 1
        observed_calls.first.should == {rv: 42}
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

        observed_calls.should be_empty
      end
    end

    context 'line inside of method' do
      it 'invokes callback' do
        described_class.hook_line('hook_line.rb', 3) do |payload|
          observed_calls << payload
        end

        HookLineTestClass.new.test_method

        observed_calls.length.should == 1
        observed_calls.first.should be_a(TracePoint)
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

        observed_calls.length.should == 1
        observed_calls.first.should be_a(TracePoint)
      end
    end
  end
end
