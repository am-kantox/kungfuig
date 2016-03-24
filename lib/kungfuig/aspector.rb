module Kungfuig
  # Generic helper for massive attaching aspects
  module Aspector
    # Helper methods
    class H
      def value_to_method_list klazz, values_inc, values_exc
        [values_inc, values_exc].map do |v|
          v = [*v].map(&:to_sym)
          case
          when v.empty? then []
          when v.include?('*'), v.include?(:'*') then klazz.instance_methods(false)
          else klazz.instance_methods & v
          end
        end.reduce(&:-)
      end

      def remap_hash_for_easy_iteration hash
        hash = hash.each_with_object(Hashie::Mash.new) do |(k, v), memo|
          v.each { |m, c| memo.public_send("#{m}!")[k] = c }
        end unless (hash.keys - %w(before after exclude)).empty?
        hash.each_with_object({}) do |(k, v), memo|
          v.each { |m, h| ((memo[h] ||= {})[k.to_sym] ||= []) << m }
        end
      end

      def proc_instance string
        m, k = string.split('#').reverse
        (k ? Kernel.const_get(k).method(m) : method(m)).to_proc
      end
    end

    def attach(to, before: nil, after: nil, exclude: nil)
      klazz = case to
              when String then Kernel.const_get(to) # we are ready to get a class name
              when Class then to                    # got a class! wow, somebody has the documentation read
              else class << to; self; end           # attach to klazz’s eigenclass if object given
              end

      raise ArgumentError, "Trying to attach nothing to #{klazz}##{to}. I need a block!" unless block_given?
      klazz.send(:include, Kungfuig::Aspector) unless klazz.ancestors.include? Kungfuig::Aspector
      cb = Proc.new

      H.new.value_to_method_list(klazz, before, exclude).each do |m|
        # FIXME: log methods that failed to be wrapped more accurately? # Kungfuig.✍(klazz, m, e.inspect)
        klazz.aspect(m, false, &cb)
      end unless before.nil?

      H.new.value_to_method_list(klazz, after, exclude).each do |m|
        # FIXME: log methods that failed to be wrapped more accurately? # Kungfuig.✍(klazz, m, e.inspect)
        klazz.aspect(m, true, &cb)
      end unless after.nil?

      klazz.aspects
    end
    module_function :attach

    # 'Test':
    #   after:
    #     'yo': 'YoCalledAsyncHandler#process'
    #     'yo1' : 'YoCalledAsyncHandler#process'
    #   before:
    #     'yo': 'YoCalledAsyncHandler#process'
    def bulk(hos)
      Kungfuig.load_stuff(hos).map do |klazz, hash|
        next if hash.empty?
        [klazz, H.new.remap_hash_for_easy_iteration(hash).map do |handler, methods|
          begin
            attach(klazz, **methods, &H.new.proc_instance(handler))
          rescue => e
            raise ArgumentError, [
              "Bad input to Kungfuig::Aspector##{__callee__}.",
              "Args: #{methods.inspect}",
              "Original exception: “#{e.message}”.",
              e.backtrace.unshift("Backtrace:").join("#{$/}⮩  ")
            ].join($/.to_s)
          end
        end]
      end.compact.to_h
    end
    module_function :bulk

    private_constant :H
  end
end
