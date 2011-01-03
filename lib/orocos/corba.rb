require 'rorocos_ext'
require 'typelib'

module Orocos
    module CORBA
        extend Logger::Forward
        extend Logger::Hierarchy

        class << self
            # The address at which to contact the CORBA naming service
            attr_reader :name_service

            def name_service=(hostname)
                if initialized?
                    raise "the hostname for the CORBA name service can only be changed before the CORBA layer is initialized"
                end

                @name_service = hostname
            end

            # The maximum message size, in bytes, allowed by the omniORB. It can
            # only be set before Orocos.initialize is called
            #
            # Orocos.rb sets it to 4MB by default
            attr_reader :max_message_size

            def max_message_size=(value)
                if initialized?
                    raise "the maximum message size can only be changed before the CORBA layer is initialized"
                end

                ENV['ORBgiopMaxMsgSize'] = value.to_int.to_s
            end
        end
        @name_service     = "127.0.0.1"

        # Removes dangling references from the name server
        #
        # This method removes objects that are not accessible anymore from the
        # name server
        def self.cleanup
            names = Orocos.task_names.dup
            names.each do |n|
                begin
                    CORBA.info "trying task context #{n}"
                    TaskContext.get(n)
                rescue Orocos::NotFound
                    CORBA.warn "unregistered dangling CORBA name #{n}"
                end
            end
        end

        class << self
            # Returns the current timeout for method calls, in milliseconds
            #
            # See #call_timeout= for a complete description
            attr_reader :call_timeout

            # Sets the timeout, in milliseconds, for a CORBA method call to be
            # completed. It means that no method call can exceed the specified
            # value.
            def call_timeout=(value)
                do_call_timeout(value)
                @call_timeout = value
            end

            # Returns the timeout, in milliseconds, before a connection creation
            # fails.
            #
            # See #connect_timeout=
            attr_reader :connect_timeout

            # Sets the timeout, in milliseconds, before a connection creation
            # fails.
            def connect_timeout=(value)
                do_connect_timeout(value)
                @connect_timeout = value
            end
        end

        # For backward compatibility reasons. Use Orocos.load_typekit instead
        def self.load_typekit(name)
            Orocos.load_typekit(name)
        end

        # Initialize the CORBA layer
        # 
        # It does not need to be called explicitely, as it is called by
        # Orocos.initialize
	def self.init
	    ENV['ORBInitRef'] ||= "NameService=corbaname::#{CORBA.name_service}"
            do_init
            self.connect_timeout = 100
	end

        # Improves exception messages for exceptions that are raised from the
        # C++ extension
        def self.refine_exceptions(obj0, obj1 = nil) # :nodoc:
            yield

        rescue ComError => e
            if !obj1
                raise ComError, "communication failed with #{obj0}", e.backtrace
            else
                raise ComError, "communication failed with either #{obj0} or #{obj1}", e.backtrace
            end
        end
    end
end

