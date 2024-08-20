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

      def redacted_identifiers
        @redacted_identifiers ||= begin
          names = DEFAULT_REDACTED_IDENTIFIERS + settings.internal_dynamic_instrumentation.redacted_identifiers
          names.map! do |name|
            normalize(name)
          end
          Set.new(*names)
        end
      end

      def redact_identifier?(name)
        redacted_identifiers.include?(normalize(name))
      end

      def maybe_redact_identifier(name)
        if redact_identifier?(name)
          PLACEHOLDER
        else
          if block_given?
            yield name
          else
            name
          end
        end
      end

      def redact_type?(name)
        redacted_types.include?(name)
      end

      def maybe_redact_type(name)
        if redact_type?(name)
          PLACEHOLDER
        else
          if block_given?
            yield name
          else
            name
          end
        end
      end

      def redacted_types
        @redacted_types ||= settings.internal_dynamic_instrumentation.redacted_types
      end

      private

      PLACEHOLDER = '[redacted]'

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

      def normalize(str)
        str.strip.downcase.gsub('_', '')
      end
    end
  end
end
