if RUBY_PLATFORM != 'java'
  gem 'byebug'
end
gem 'rfc'
eval_gemfile("#{RUBY_ENGINE}-#{RUBY_ENGINE_VERSION.split('.').take(2).join('.')}.gemfile")
if RUBY_VERSION < '3'
gem 'ffi', '~>1.16.0'
end
