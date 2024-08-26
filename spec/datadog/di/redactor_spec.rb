require 'datadog/di/serializer'

RSpec.describe Datadog::DI::Redactor do
  let(:settings) do
    double('settings').tap do |settings|
      allow(settings).to receive(:internal_dynamic_instrumentation).and_return(di_settings)
    end
  end

  let(:di_settings) do
    double('di settings').tap do |settings|
      allow(settings).to receive(:enabled).and_return(true)
      allow(settings).to receive(:propagate_all_exceptions).and_return(false)
      allow(settings).to receive(:redacted_identifiers).and_return([])
    end
  end

  let(:redactor) do
    Datadog::DI::Redactor.new(settings)
  end

  describe '#redact_identifier?' do
    CASES = [
      ['lowercase', 'password', true],
      ['uppercase', 'PASSWORD', true],
      ['with removed punctiation', 'pass_word', true],
      ['with non-removed punctuation', 'pass/word', false],
    ]

    CASES.each do |(label, identifier_, redact_)|
      identifier, redact = identifier_, redact_

      context label do
        let(:identifier) { identifier }

        it do
          expect(redactor.redact_identifier?(identifier)).to be redact
        end
      end
    end
  end

  describe '#redact_type?' do
    class SensitiveType; end

    let(:redacted_type_names) { %w[SensitiveType WildCard*] }

    class WildCardClass; end

    before do
      expect(di_settings).to receive(:redacted_type_names).and_return(redacted_type_names)
    end

    CASES = [
      ['redacted', SensitiveType.new, true],
      ['not redacted', /123/, false],
      ['primitive type', nil, false],
      ['wild card type', WildCardClass.new, true],
    ]

    CASES.each do |(label, value_, redact_)|
      value, redact = value_, redact_

      context label do
        let(:value) { value }

        it do
          expect(redactor.redact_type?(value)).to be redact
        end
      end
    end
  end
end
