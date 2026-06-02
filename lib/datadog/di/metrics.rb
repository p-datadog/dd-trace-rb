# frozen_string_literal: true

module Datadog
  module DI
    # Helper for emitting DI guardrail/observability metrics to the
    # instrumentation telemetry channel under the `debugger` namespace.
    #
    # Backs the metrics defined in the
    # "Debugger Guardrails and Observability for GA" RFC, which prefixes
    # every metric name with `debugger.`. dd-trace-rb's telemetry pipeline
    # separates namespace and metric name on the wire, so we pass
    # namespace=`debugger` and metric_name=`events.skipped`,
    # `capture.duration`, etc.
    #
    # @api private
    module Metrics
      NAMESPACE = 'debugger'

      EVENTS_SKIPPED = 'events.skipped'
      EVENTS_DROPPED = 'events.dropped'
      EVALUATION_DURATION = 'evaluation.duration'
      CAPTURE_DURATION = 'capture.duration'
      CAPTURE_INCOMPLETE = 'capture.incomplete'
      EVALUATION_ERRORS = 'evaluation.errors'
      PROBES_COUNT = 'probes.count'

      # Tag values for the `event_type` tag.
      #
      # Resolution of the RFC's `snapshot | log | metric | span | diagnostic`
      # enum against Ruby's probe model (which only has `:log` probes with
      # orthogonal `captureSnapshot`/`captureExpressions` flags) is performed
      # by {.event_type_for_probe}; status notifications use {DIAGNOSTIC}.
      module EventType
        SNAPSHOT = 'snapshot'
        LOG = 'log'
        DIAGNOSTIC = 'diagnostic'
      end

      # Tag values for the `evaluation_kind` tag.
      module EvaluationKind
        CONDITION = 'condition'
        TEMPLATE = 'template'
        # Ruby-specific: capture-expression evaluation is a third evaluation
        # kind not listed in the RFC enum (snapshot/log/diagnostic only). We
        # emit `capture_expression` so the time/error volume is not folded
        # into condition/template and silently double-counted.
        CAPTURE_EXPRESSION = 'capture_expression'
      end

      # `events.skipped.reason` values.
      module SkipReason
        RATE_LIMIT_GLOBAL = 'rateLimitGlobal'
        RATE_LIMIT_PROBE = 'rateLimitProbe'
        EVALUATION_TIMEOUT = 'evaluationTimeout'
        EVALUATION_ERROR_THROTTLED = 'evaluationErrorThrottled'
        # Ruby-specific: emitted when the global kill switch (remote-config
        # `dynamic_instrumentation_enabled=false`) suppresses event creation.
        # Not listed in the RFC `events.skipped.reason` enum; emitted only
        # in the narrow window between kill-switch flip and worker drain.
        KILL_SWITCH = 'killSwitch'
      end

      # `events.dropped.reason` values.
      module DropReason
        QUEUE_FULL = 'queueFull'
        # Ruby-specific extension. The RFC defines `payloadTooLarge` only on
        # `capture.incomplete` (which assumes the payload is trimmed to fit).
        # Ruby drops oversized payloads whole, so we route it to
        # `events.dropped` instead and document the deviation.
        PAYLOAD_TOO_LARGE = 'payloadTooLarge'
      end

      # `capture.incomplete.reason` values.
      module IncompleteReason
        RUNTIME_ERROR = 'runtimeError'
        CAPTURE_TIMEOUT = 'captureTimeout'
        DEPTH_LIMIT = 'depthLimit'
        FIELD_LIMIT = 'fieldLimit'
        COLLECTION_LIMIT = 'collectionLimit'
        STRING_LIMIT = 'stringLimit'
        PAYLOAD_TOO_LARGE = 'payloadTooLarge'
        OTHER = 'other'
      end

      # `probe_status` values for the `probes.count` gauge.
      module ProbeStatus
        RECEIVED = 'received'
        INSTALLED = 'installed'
        EMITTING = 'emitting'
        BLOCKED = 'blocked'
        ERROR = 'error'
      end

      module_function

      # Resolves Ruby's probe shape against the RFC `event_type` enum.
      #
      # Ruby has only `:log` probes (lib/datadog/di/probe.rb KNOWN_TYPES),
      # but the RFC enum splits `log` and `snapshot`. We tag any probe with
      # `captureSnapshot=true` or one or more `captureExpressions` as
      # `snapshot`, on the basis that the wire-format event carries
      # snapshot-shaped data. Plain `log` (template + condition only)
      # remains `log`.
      def event_type_for_probe(probe)
        if probe.capture_snapshot? || probe.capture_expressions?
          EventType::SNAPSHOT
        else
          EventType::LOG
        end
      end

      # Best-effort wrapper. Telemetry emission must never break DI: the
      # tracer-error reporting channel is itself accessed via the same
      # `telemetry` handle, and in tests `telemetry` is often a strict
      # double that only accepts specific messages (`RSpec::Mocks::
      # MockExpectationError` inherits from Exception, not StandardError).
      def safe_emit
        yield
      rescue Exception # rubocop:disable Lint/RescueException
        nil
      end

      # Emits an `events.skipped` count.
      def emit_skipped(telemetry, reason:, probe: nil, event_type: nil)
        return unless telemetry

        tags = { 'reason' => reason }
        if probe
          tags['event_type'] = event_type || event_type_for_probe(probe)
          tags['probe_id'] = probe.id
        elsif event_type
          tags['event_type'] = event_type
        end
        safe_emit { telemetry.inc(NAMESPACE, EVENTS_SKIPPED, 1, tags: tags) }
      end

      # Emits an `events.dropped` count.
      def emit_dropped(telemetry, reason:, probe: nil, event_type: nil)
        return unless telemetry

        tags = { 'reason' => reason }
        if probe
          tags['event_type'] = event_type || event_type_for_probe(probe)
          tags['probe_id'] = probe.id
        elsif event_type
          tags['event_type'] = event_type
        end
        safe_emit { telemetry.inc(NAMESPACE, EVENTS_DROPPED, 1, tags: tags) }
      end

      # Emits a `capture.duration` distribution in milliseconds.
      def emit_capture_duration_ms(telemetry, duration_ms, event_type:)
        return unless telemetry

        safe_emit do
          telemetry.distribution(NAMESPACE, CAPTURE_DURATION, duration_ms,
            tags: { 'event_type' => event_type })
        end
      end

      # Emits a `capture.incomplete` count.
      def emit_capture_incomplete(telemetry, reason:, probe: nil, event_type: nil)
        return unless telemetry

        tags = { 'reason' => reason }
        if probe
          tags['event_type'] = event_type || event_type_for_probe(probe)
          tags['probe_id'] = probe.id
        elsif event_type
          tags['event_type'] = event_type
        end
        safe_emit { telemetry.inc(NAMESPACE, CAPTURE_INCOMPLETE, 1, tags: tags) }
      end

      # Emits an `evaluation.duration` distribution in milliseconds.
      def emit_evaluation_duration_ms(telemetry, duration_ms, event_type:, evaluation_kind:)
        return unless telemetry

        safe_emit do
          telemetry.distribution(NAMESPACE, EVALUATION_DURATION, duration_ms,
            tags: {
              'event_type' => event_type,
              'evaluation_kind' => evaluation_kind,
            })
        end
      end

      # Emits an `evaluation.errors` count.
      def emit_evaluation_error(telemetry, probe:, evaluation_kind: nil)
        return unless telemetry

        tags = {
          'event_type' => event_type_for_probe(probe),
          'probe_id' => probe.id,
        }
        tags['evaluation_kind'] = evaluation_kind if evaluation_kind
        safe_emit { telemetry.inc(NAMESPACE, EVALUATION_ERRORS, 1, tags: tags) }
      end

      # Emits a `probes.count` gauge.
      def emit_probes_count(telemetry, count, event_type:, probe_status:)
        return unless telemetry

        safe_emit do
          telemetry.gauge(NAMESPACE, PROBES_COUNT, count,
            tags: {
              'event_type' => event_type,
              'probe_status' => probe_status,
            })
        end
      end
    end
  end
end
