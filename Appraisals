lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'datadog/version'

module DisableBundleCheck
  def check_command
    ['bundle', 'exec', 'false']
  end
end

::Appraisal::Appraisal.prepend(DisableBundleCheck) if ['true', 'y', 'yes', '1'].include?(ENV['APPRAISAL_SKIP_BUNDLE_CHECK'])

alias original_appraise appraise

REMOVED_GEMS = {
  :check => [
    'rbs',
    'steep',
  ],
  :dev => [
    'ruby-lsp',
  ],
}

def appraise(group, &block)
  # Specify the environment variable APPRAISAL_GROUP to load only a specific appraisal group.
  if ENV['APPRAISAL_GROUP'].nil? || ENV['APPRAISAL_GROUP'] == group
    original_appraise(group) do
      instance_exec(&block)

      REMOVED_GEMS.each do |group_name, gems|
        group(group_name) do
          gems.each do |gem_name|
            # appraisal 2.2 doesn't have remove_gem, which applies to ruby 2.1 and 2.2
            remove_gem gem_name if respond_to?(:remove_gem)
          end
        end
      end
    end
  end
end

major, minor, = if defined?(RUBY_ENGINE_VERSION)
                  Gem::Version.new(RUBY_ENGINE_VERSION).segments
                else
                  # For Ruby < 2.3
                  Gem::Version.new(RUBY_VERSION).segments
                end

ruby_runtime = "#{RUBY_ENGINE}-#{major}.#{minor}"

instance_eval IO.read("appraisal/#{ruby_runtime}.rb")

appraisals.each do |appraisal|
  appraisal.name.prepend("#{ruby_runtime}-")
end

# vim: ft=ruby
