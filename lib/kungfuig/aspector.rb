module Kungfuig
  # Generic helper for massive attaching aspects
  module Aspector
    # Helper methods
    class H
      def value_to_method_list klazz, values_inc, values_exc
        # FIXME MOVE JOKER HANDLING INTO PREPENDER !!!!
        if klazz.is_a?(Module)
          [values_inc, values_exc].map do |v|
            v = [*v].map(&:to_sym)
            case
            when v.empty? then []
            when v.include?('*'), v.include?(:'*') then klazz.instance_methods(false)
            else klazz.instance_methods & v
            end
          end.reduce(&:-) - klazz.instance_methods(false).select { |m| m.to_s.start_with?('to_') }
        else
          # NOT YET IMPLEMENTED FIXME MOVE TO PREPENDER
          [values_inc, values_exc].map do |v|
            [*v].map(&:to_sym)
          end.reduce(&:-) - [:'*']
        end
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

      def try_to_class name
        Kernel.const_defined?(name.to_s) ? Kernel.const_get(name.to_s) : name
      end
    end

    def attach(to, before: nil, after: nil, exclude: nil)
      raise ArgumentError, "Trying to attach nothing to #{klazz}##{to}. I need a block!" unless block_given?

      cb = Proc.new

      klazz = case to
              when Module then to # got a class! wow, somebody has the documentation read
              when String, Symbol then H.new.try_to_class(to) # we are ready to get a class name
              else class << to; self; end # attach to klazz’s eigenclass if object given
              end

      { before: before, after: after }.each do |k, var|
        H.new.value_to_method_list(klazz, var, exclude).each do |m|
          Kungfuig::Prepender.new(to, m).public_send(k, &cb)
        end unless var.nil?
      end

      klazz.is_a?(Module) ? klazz.aspects : { promise: klazz }
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
              "Original exception: #{e.message}.",
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
