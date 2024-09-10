# frozen_string_literal: true

module Datadog
  module DI
    #
    # @api private
    class Redactor
      def initialize(settings)
        @settings = settings
      end

      attr_reader :settings

      def redact_identifier?(name)
        redacted_identifiers.include?(normalize(name))
      end

      def redact_type?(value)
        # Classses can be nameless, do not attempt to redact in that case.
        if cls_name = value.class.name
          redacted_type_names_regexp.match?(cls_name)
        else
          false
        end
      end

      private

      def redacted_identifiers
        @redacted_identifiers ||= begin
          names = DEFAULT_REDACTED_IDENTIFIERS + settings.dynamic_instrumentation.redacted_identifiers
          names.map! do |name|
            normalize(name)
          end
          Set.new(names)
        end
      end

      def redacted_type_names_regexp
        @redacted_type_names_regexp ||= begin
          names = settings.dynamic_instrumentation.redacted_type_names
          names = names.map do |name|
            if name.end_with?('*')
              name = name[0..-2]
              suffix = '.*'
            else
              suffix = ''
            end
            Regexp.escape(name) + suffix
          end.join('|')
          Regexp.new("\\A(?:#{names})\\z")
        end
      end

      # Copied from dd-trace-py
      DEFAULT_REDACTED_IDENTIFIERS = [
        "2fa",
        "accesstoken",
        "aiohttpsession",
        "apikey",
        "apisecret",
        "apisignature",
        "appkey",
        "applicationkey",
        "auth",
        "authorization",
        "authtoken",
        "ccnumber",
        "certificatepin",
        "cipher",
        "clientid",
        "clientsecret",
        "connectionstring",
        "connectsid",
        "cookie",
        "credentials",
        "creditcard",
        "csrf",
        "csrftoken",
        "cvv",
        "databaseurl",
        "dburl",
        "encryptionkey",
        "encryptionkeyid",
        "env",
        "geolocation",
        "gpgkey",
        "ipaddress",
        "jti",
        "jwt",
        "licensekey",
        "masterkey",
        "mysqlpwd",
        "nonce",
        "oauth",
        "oauthtoken",
        "otp",
        "passhash",
        "passwd",
        "password",
        "passwordb",
        "pemfile",
        "pgpkey",
        "phpsessid",
        "pin",
        "pincode",
        "pkcs8",
        "privatekey",
        "publickey",
        "pwd",
        "recaptchakey",
        "refreshtoken",
        "routingnumber",
        "salt",
        "secret",
        "secretkey",
        "secrettoken",
        "securityanswer",
        "securitycode",
        "securityquestion",
        "serviceaccountcredentials",
        "session",
        "sessionid",
        "sessionkey",
        "setcookie",
        "signature",
        "signaturekey",
        "sshkey",
        "ssn",
        "symfony",
        "token",
        "transactionid",
        "twiliotoken",
        "usersession",
        "voterid",
        "xapikey",
        "xauthtoken",
        "xcsrftoken",
        "xforwardedfor",
        "xrealip",
        "xsrf",
        "xsrftoken",
      ]

      # Input can be a string or a symbol.
      def normalize(str)
        str.to_s.strip.downcase.gsub(/[-_$@]/, '')
      end
    end
  end
end
