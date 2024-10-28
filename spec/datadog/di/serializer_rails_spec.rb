require "datadog/di/spec_helper"
require "datadog/di/serializer"
require_relative 'serializer_helper'
require 'active_record'
require 'sqlite3'
require "datadog/di/contrib/active_record"

class SerializerRailsSpecTestModel < ActiveRecord::Base
end

RSpec.describe Datadog::DI::Serializer do
  di_test

  extend SerializerHelper

  before(:all) do
    @original_config = begin
      if defined?(::ActiveRecord::Base.connection_db_config)
        ::ActiveRecord::Base.connection_db_config
      else
        ::ActiveRecord::Base.connection_config
      end
    rescue ActiveRecord::ConnectionNotEstablished
    end

    ActiveRecord::Base.establish_connection('sqlite3::memory:')

    ActiveRecord::Schema.define(version: 20161003090450) do
      create_table 'serializer_rails_spec_test_models', force: :cascade do |t|
        t.string   'title'
        t.datetime 'created_at', null: false
        t.datetime 'updated_at', null: false
      end
    end

  end

  after(:all) do
    ::ActiveRecord::Base.establish_connection(@original_config) if @original_config
  end

  let(:redactor) do
    Datadog::DI::Redactor.new(settings)
  end

  default_settings

  let(:serializer) do
    described_class.new(settings, redactor)
  end

  describe "#serialize_value" do
    let(:serialized) do
      serializer.serialize_value(value, **options)
    end

    cases = [
      {name: "AR model", input: -> { SerializerRailsSpecTestModel.new }, expected: {type: "NilClass", isNull: true}},
    ]

    define_serialize_value_cases(cases)
  end
end
