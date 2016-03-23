require 'kungfuig/version'
require 'yaml'
require 'hashie'

module Kungfuig
  ASPECT_PREFIX = '♻_'.freeze
  MX = Mutex.new

  module InstanceMethods
    # Configures everything by hash or yaml from string or file. Whether code block
    #   is passed, it is processed with @options instance.
    # @param hos [String|Hash|Hashie::Mash] the input data to merge into options
    def config hos = nil
      MX.synchronize {
        merge_hash_or_string! hos
        yield options if block_given?
        options
      }
    end

    # Options getter
    # @return [Hashie::Mash] options
    def options
      @options ||= Hashie::Mash.new
    end
    private :options

    # Accepts:
    #     option :foo, :bar, 'baz'
    #     option [:foo, 'bar', 'baz']
    #     option 'foo.bar.baz'
    #     option 'foo::bar::baz'
    def option *keys
      key = keys.join('.').gsub(/::/, '.').split('.')

      MX.synchronize {
        # options.foo!.bar!.baz!
        [key, key[1..-1]].map do |candidate|
          candidate.inject(options.dup) do |memo, k|
            memo.public_send(k.to_s) unless memo.nil?
          end
        end.detect { |e| e }
      }
    end

    # Accepts:
    #     option! [:foo, 'bar', 'baz'], value
    #     option! 'foo.bar.baz', value
    #     option! 'foo::bar::baz', value
    def option! keys, value
      key = (keys.is_a?(Array) ? keys.join('.') : keys).gsub(/::/, '.').split('.')
      last = key.pop

      MX.synchronize {
        # options.foo!.bar!.baz! = value
        build = key.inject(options) do |memo, k|
          memo.public_send("#{k}!")
        end
        build[last] = value
      }
    end

    def option? *keys
      !option(*keys).nil?
    end

    # rubocop:disable Metrics/AbcSize
    # rubocop:disable Metrics/CyclomaticComplexity
    # rubocop:disable Metrics/MethodLength
    # @param hos [Hash|String] the new values taken from hash,
    #   mash or string (when string, should be either valid YAML file name or
    #   string with valid YAML)
    def merge_hash_or_string! hos
      options.deep_merge! case hos
                          when NilClass then Hashie::Mash.new # aka skip
                          when Hash then Hashie::Mash.new(hos)
                          when String
                            begin
                              File.exist?(hos) ? Hashie::Mash.load(hos) : Hashie::Mash.new(YAML.load(hos)).tap do |opts|
                                fail ArgumentError.new "#{__callee__} expects valid YAML configuration file or YAML string." unless opts.is_a?(Hash)
                              end
                            rescue ArgumentError
                              fail ArgumentError.new "#{__callee__} expects valid YAML configuration file. [#{hos}] contains invalid syntax."
                            rescue Psych::SyntaxError
                              fail ArgumentError.new "#{__callee__} expects valid YAML configuration string. Got:\n#{hos}"
                            end
                          when ->(h) { h.respond_to?(:to_hash) } then Hashie::Mash.new(h.to_hash)
                          else
                            fail ArgumentError.new "#{__callee__} accepts either String or Hash as parameter."
                          end
    end
    # rubocop:enable Metrics/MethodLength
    # rubocop:enable Metrics/CyclomaticComplexity
    # rubocop:enable Metrics/AbcSize
    private :merge_hash_or_string!
  end

  def self.included base
    base.include InstanceMethods
    base.extend ClassMethods
    if (base.instance_methods & [:[], :[]=]).empty?
      base.send :alias_method, :[], :option
      base.send :alias_method, :[]=, :option!
    end
  end

  def self.extended base
    base.include ClassMethods
  end

  module ClassMethods
    include InstanceMethods

    # A wrapper for the configuration block
    # @param block the block to be executed in the context of this module
    def kungfuig &block
      instance_eval(&block)
    end

    # rubocop:disable Metrics/MethodLength
    def aspect meth, after = true
      fail ArgumentError.new "Aspect must have a codeblock" unless block_given?
      fail NoMethodError.new "Aspect must be attached to existing method" unless instance_methods.include? meth.to_sym

      aspects(meth)[after ? :after : :before] << Proc.new

      unless instance_methods(true).include?(:"#{ASPECT_PREFIX}#{meth}")
        class_eval <<-CODE
          alias_method :#{ASPECT_PREFIX}#{meth}, :#{meth}
          def #{meth}(*args, &cb)
            ps = self.class.aspects(:#{meth})
            ps[:before].each do |p|
              p.call(*args) # TODO: make prependers able to change args!!!
            end
            send(:#{ASPECT_PREFIX}#{meth}, *args, &cb).tap do |result|
              ps[:after].each do |p|
                p.call result, *args
              end
            end
          end
        CODE
      end

      meth.to_sym
    end
    # rubocop:enable Metrics/MethodLength

    def aspects meth = nil
      @aspects ||= {}
      meth ? @aspects[meth.to_sym] ||= {after: [], before: []} : @aspects
    end
    alias_method :set, :option!
  end
end
