# frozen_string_literal: true

module ActiveRecord
  module Encryption
    # A container of attribute encryption options.
    #
    # It validates and serves attribute encryption options.
    #
    # See EncryptedAttributeType, Context
    class Scheme
      attr_accessor :previous_schemes

      def initialize(key_provider: nil, key: nil, deterministic: nil, downcase: nil, ignore_case: nil,
                     compress: nil, previous_schemes: nil, **context_properties)
        # Initializing all attributes to +nil+ as we want to allow a "not set" semantics so that we
        # can merge schemes without overriding values with defaults. See +#merge+

        @key_provider_param = key_provider
        @key = key
        @deterministic = deterministic
        @downcase = downcase || ignore_case
        @ignore_case = ignore_case
        @compress = compress
        @previous_schemes_param = previous_schemes
        @previous_schemes = Array.wrap(previous_schemes)
        @context_properties = context_properties


        validate_config!
      end

      def ignore_case?
        @ignore_case
      end

      def downcase?
        @downcase
      end

      def deterministic?
        @deterministic
      end

      def compress?
        @compress
      end

      def fixed?
        # by default deterministic encryption is fixed
        @fixed ||= @deterministic && (!@deterministic.is_a?(Hash) || @deterministic[:fixed])
      end

      def key_provider
        @key_provider ||= @key_provider_param || build_key_provider || default_key_provider
      end

      def merge(other_scheme)
        self.class.new(**to_h.merge(other_scheme.to_h))
      end

      def to_h
        { key_provider: @key_provider_param, key: @key, deterministic: @deterministic, compress: @compress, downcase: @downcase, ignore_case: @ignore_case,
          previous_schemes: @previous_schemes_param, **@context_properties }.compact
      end

      def with_context(&block)
        if @context_properties.present?
          ActiveRecord::Encryption.with_encryption_context(**@context_properties, &block)
        else
          block.call
        end
      end

      private
        def validate_config!
          raise Errors::Configuration, "ignore_case: can only be used with deterministic encryption" if @ignore_case && !@deterministic
          raise Errors::Configuration, "key_provider: and key: can't be used simultaneously" if @key_provider_param && @key
        end

        def build_key_provider
          return DerivedSecretKeyProvider.new(@key) if @key.present?

          if @deterministic
            DeterministicKeyProvider.new(ActiveRecord::Encryption.config.deterministic_key)
          end
        end

        def default_key_provider
          ActiveRecord::Encryption.key_provider
        end
    end
  end
end
