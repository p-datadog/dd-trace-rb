# frozen_string_literal: true

Datadog::DI::Serializer.register(condition: lambda { |value| ActiveRecord::Base === value }) \
do |serializer, value, name:, depth:|
  serializer.type_serialized_entry(value.class,
    serializer.serialize_value(value.attributes, depth: depth))
end
