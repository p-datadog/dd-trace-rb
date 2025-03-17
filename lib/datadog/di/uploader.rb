module Datadog
  module DI
    class Uploader
      def upload
        # For the hashing POC we need files.
        entries = []
        $LOADED_FEATURES.each do |path|
          payload = {
            service: Datadog.configuration.service,
            env: Datadog.configuration.env,
            version: Datadog.configuration.version,
            language: 'python',
            scopes: [
              {scope_type: 'FILE', source_file: path, name: path,
                symbols: [
                  {name: path, symbol_type: 'FILE', type: 'file'},
                ],
              },
            ],
          }
          entries << payload
        end
      end
    end
  end
end
