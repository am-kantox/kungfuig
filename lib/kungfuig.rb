require 'yaml'
require 'hashie'

require 'kungfuig/version'
require 'kungfuig/color'
require 'kungfuig/aspector'
require 'kungfuig/prepender'

module Kungfuig
  MX = Mutex.new

  # rubocop:disable Style/MethodName
  def ✍(receiver: nil, method: nil, result: nil, args: nil, **params)
    require 'logger'
    @✍ ||= Kernel.const_defined?('Rails') && Rails.logger || Logger.new($stdout)
    message = receiver.is_a?(String) ? "#{receiver} | #{method}" : "#{receiver.class}##{method}"
    "#{Color.to_xterm256(message, :info)} called with «#{Color.to_xterm256(args.inspect, :success)}» and returned «#{result || 'nothing (was it before aspect?)'}»".tap do |m|
      @✍.debug m
    end
  end
  module_function :✍
  # rubocop:enable Style/MethodName

  def load_stuff hos
    case hos
    when NilClass then Hashie::Mash.new # aka skip
    when Hash then Hashie::Mash.new(hos)
    when String
      begin
        File.exist?(hos) ? Hashie::Mash.load(hos) : Hashie::Mash.new(YAML.load(hos))
      rescue ArgumentError
        fail ArgumentError, "#{__callee__} expects valid YAML configuration file. “#{hos.inspect}” contains invalid syntax."
      rescue Psych::SyntaxError
        fail ArgumentError, "#{__callee__} expects valid YAML configuration string. Got:\n#{hos.inspect}"
      rescue
        fail ArgumentError, "#{__callee__} expects valid YAML configuration string (misspelled file name?). Got:\n#{hos.inspect}"
      end
    when ->(h) { h.respond_to?(:to_hash) } then Hashie::Mash.new(h.to_hash)
    else
      fail ArgumentError.new "#{__callee__} accepts either String or Hash as parameter."
    end
  end
  module_function :load_stuff

  module InstanceMethods
    # Configures everything by hash or yaml from string or file. Whether code block
    #   is passed, it is processed with @options instance.
    # @param hos [String|Hash|Hashie::Mash] the input data to merge into options
    def kungfuig hos = nil
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

    # @param hos [Hash|String] the new values taken from hash,
    #   mash or string (when string, should be either valid YAML file name or
    #   string with valid YAML)
    def merge_hash_or_string! hos
      options.deep_merge! Kungfuig.load_stuff hos
    end
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
    def kungfuigure &block
      instance_eval(&block)
    end

    def aspect meth, after = true
      fail ArgumentError.new "Aspect must have a codeblock" unless block_given?
      fail NoMethodError.new "Aspect must be attached to existing method" unless instance_methods.include? meth.to_sym

      Kungfuig::Prepender.new(self, meth).public_send((after ? :after : :before), &Proc.new)
    end

    def aspects
      ancestors.select { |a| a.name.nil? && a.ancestors.include?(I★I) }
               .flat_map { |m| m.instance_methods(false) }
               .group_by { |e| e }
               .map { |k, v| [k, v.count] }.to_h
    end
    alias_method :set, :option!
  end
end
