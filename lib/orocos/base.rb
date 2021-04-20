# The Orocos main class
module Orocos
    # Result value when reading a port whose value has already been read
    #
    # Unlike within RTT, 'NO_DATA' is represented by a false value
    #
    # @see NEW_DATA
    OLD_DATA = 0

    # Result value when reading a port which has a new (never read) value
    #
    # Unlike within RTT, 'NO_DATA' is represented by a false value
    #
    # @see OLD_DATA
    NEW_DATA = 1

    class AlreadyInitialized < RuntimeError; end
    class InternalError < RuntimeError; end
    class AmbiguousName < RuntimeError; end
    class PropertyChangeRejected < RuntimeError; end
    # @deprecated use OroGen::ConfigError instead
    ConfigError = OroGen::ConfigError

    class NotFound < RuntimeError; end
    class TypekitNotFound < NotFound; end
    TypekitTypeNotFound    = OroGen::NotTypekitType
    TypekitTypeNotExported = OroGen::NotExportedType

    # Emitted when an interface object is requested, that does not exist
    class InterfaceObjectNotFound < Orocos::NotFound
        attr_reader :task
        attr_reader :name

        def initialize(task, name)
            @task = task
            @name = name
            super()
        end
    end

    def self.register_pkgconfig_path(path)
    	base_path = caller(1).first.gsub(/:\d+:.*/, '')
	ENV['PKG_CONFIG_PATH'] = "#{File.expand_path(path, File.dirname(base_path))}:#{ENV['PKG_CONFIG_PATH']}"
    end

    # Exception raised when the user tries an operation that requires the
    # component to be generated by oroGen, while the component is not
    class NotOrogenComponent < Exception; end

    # Base class for all exceptions related to communication with remote
    # processes
    class ComError < RuntimeError; end

    class << self
        # The main configuration manager object
        attr_reader :conf

        # The registry that is the union of all loaded typekits
        #
        # @return [Typelib::Registry]
        def registry
            default_loader.registry
        end

        # A project that can be used to create models on-the-fly using
        # {Orocos.default_loader}
        def default_project
            @default_project ||= OroGen::Spec::Project.new(Orocos.default_loader)
        end

        # If true, the orocos logfile that is being generated by this Ruby
        # process is kept. By default, it gets removed when the ruby process
        # terminates
        attr_predicate :keep_orocos_logfile?, true

        # The name of the orocos logfile for this Ruby process
        attr_reader :orocos_logfile

        # [RubyTasks::TaskContext] the ruby task context that is used to provide a RTT
        # interface to this Ruby process. Among other things, it manages the
        # data readers and writers
        attr_reader :ruby_task

        @@ruby_task_sync = Mutex.new

        # Protect access to {#ruby_task} in multithreading contexts
        def ruby_task_access(&block)
            @@ruby_task_sync.synchronize(&block)
        end

        attr_predicate :warn_for_missing_default_loggers?, true
    end
    @use_mq_warning = true
    @keep_orocos_logfile = false
    @warn_for_missing_default_loggers = true

    # The loader object that should be used to load typekits and projects
    #
    # @return [OroGen::Loaders::Aggregate]
    # @see default_loader
    def self.default_loader
        if !@default_loader
            @default_loader = DefaultLoader.new
            # Instanciate all the sub-loaders
            default_pkgconfig_loader
            default_file_loader
            ROS.default_loader
        end
        @default_loader
    end

    # The loader object that should be used to register additional oroGen models
    #
    # @return [OroGen::Loaders::Files]
    def self.default_file_loader
        Orocos.default_loader
        @default_file_loader ||= OroGen::Loaders::Files.new(default_loader)
    end

    # The loader object that should be used to load installed oroGen typekits
    # and projects
    #
    # @return [OroGen::Loaders::PkgConfig]
    # @see default_loader
    def self.default_pkgconfig_loader
        Orocos.default_loader
        @default_pkgconfig_loader ||= OroGen::Loaders::PkgConfig.new(orocos_target, default_loader)
    end

    @macos =  RbConfig::CONFIG["host_os"] =~%r!([Dd]arwin)!
    def self.macos?
        @macos
    end

    @windows = RbConfig::CONFIG["host_os"] =~%r!(msdos|mswin|djgpp|mingw|[Ww]indows)!
    def self.windows?
        @windows
    end

    def self.shared_library_suffix
        if macos? then 'dylib'
        elsif windows? then 'dll'
        else 'so'
        end
    end

    def self.orocos_target
        if ENV['OROCOS_TARGET']
            ENV['OROCOS_TARGET']
        else
            'gnulinux'
        end
    end

    class << self
        # The set of extension names seen so far
        #
        # Whenever a new extension is encountered, Orocos.task_model_from_name
        # tries to require 'extension_name/runtime', which might no exist. Once
        # it has done that, it registers the extension name in this set to avoid
        # trying loading it again
        attr_reader :known_orogen_extensions
    end
    @known_orogen_extensions = Set.new

    # Loads a directory containing configuration files
    #
    # See the documentation of ConfigurationManager#load_dir for more
    # information
    def self.load_config_dir(dir)
        conf.load_dir(dir)
    end

    def self.load_extension_runtime_library(extension_name)
        if !known_orogen_extensions.include?(extension_name)
            begin
                require "runtime/#{extension_name}"
            rescue LoadError
            end
            known_orogen_extensions << extension_name
        end
    end

    # Returns true if Orocos.load has been called
    def self.loaded?
        @loaded
    end

    def self.load(name = nil)
        if @loaded
            raise AlreadyInitialized, "Orocos is already loaded. Try to call 'clear' before callign load a second time."
        end

        if ENV['ORO_LOGFILE'] && orocos_logfile && (ENV['ORO_LOGFILE'] != orocos_logfile)
            raise "trying to change the path to ORO_LOGFILE from #{orocos_logfile} to #{ENV['ORO_LOGFILE']}. This is not supported"
        end
        ENV['ORO_LOGFILE'] ||= File.expand_path("orocos.#{name || 'orocosrb'}-#{::Process.pid}.txt")
        @orocos_logfile = ENV['ORO_LOGFILE']

        @conf = ConfigurationManager.new
        @loaded_typekit_plugins.clear
        @max_sizes = Hash.new { |h, k| h[k] = Hash.new }

        load_typekit 'std'
        load_standard_typekits

        if Orocos::ROS.enabled?
            if !Orocos::ROS.loaded?
                # Loads all ROS projects that can be found in
                # Orocos::ROS#spec_search_directories
                Orocos::ROS.load
            end
        end
        @loaded = true

        nil
    end

    def self.clear
        if !keep_orocos_logfile? && orocos_logfile
            FileUtils.rm_f orocos_logfile
        end

        @ruby_task.dispose if @ruby_task
        default_loader.clear
        known_orogen_extensions.clear

        @max_sizes.clear

        Orocos::CORBA.clear
        @name_service = nil
        if defined? Orocos::Async
            Orocos::Async.clear
        end
        if Orocos::ROS.enabled?
            Orocos::ROS.clear
        end
        @loaded = false
        @initialized = false
    end

    def self.reset
        clear
        load
    end

    class << self
        attr_predicate :disable_sigchld_handler, true
    end

    # Returns true if Orocos.initialize has been called and completed
    # successfully
    def self.initialized?
        @initialized
    end

    # Initialize the Orocos communication layer and load all the oroGen models
    # that are available.
    #
    # This method will verify that the pkg-config environment is sane, as it is
    # demanded by the oroGen deployments. If it is not the case, it will raise
    # a RuntimeError exception whose message will describe the particular
    # problem. See the "Error messages" package in the user's guide for more
    # information on how to fix those.
    def self.initialize(name = "orocosrb_#{::Process.pid}")
        if !loaded?
            self.load(name)
        end

        # Install the SIGCHLD handler if it has not been disabled
        if !disable_sigchld_handler?
            trap('SIGCHLD') do
                begin
                    while dead = ::Process.wait(-1, ::Process::WNOHANG)
                        if mod = Orocos::Process.from_pid(dead)
                            mod.dead!($?)
                        end
                    end
                rescue Errno::ECHILD
                end
            end
        end

        if !Orocos::CORBA.initialized?
            Orocos::CORBA.initialize
        end
        @initialized = true

        if Orocos::ROS.enabled?
            # ROS does not support being teared down and reinitialized.
            if !Orocos::ROS.initialized?
                Orocos::ROS.initialize(name)
            end
        end

        # add default name services
        self.name_service << Orocos::CORBA.name_service
        if defined?(Orocos::ROS) && Orocos::ROS.enabled?
            self.name_service << Orocos::ROS.name_service
        end
        if defined?(Orocos::Async)
            Orocos.name_service.name_services.each do |ns|
                Orocos::Async.name_service.add(ns)
            end
        end
        @ruby_task = RubyTasks::TaskContext.new(name)
    end

    def self.create_orogen_task_context_model(name = nil)
        OroGen::Spec::TaskContext.new(default_project, name)
    end
    def self.create_orogen_deployment_model(name = nil)
        OroGen::Spec::Deployment.new(default_project, name)
    end

    # @deprecated access default_loader.task_model_from_name directly instead
    def self.task_model_from_name(*args, &block)
        default_loader.task_model_from_name(*args, &block)
    end

    # Calls a block with the no-blocking-call-in-thread check disabled
    #
    # This is used in tests, when we know we want to do a remote call, or in
    # places where it is guaranteed that the "remote" is actually co-localized
    # within the same process (e.g. readers, writers, ruby task context)
    def self.allow_blocking_calls
        if block_given?
            forbidden = Orocos.no_blocking_calls_in_thread
            if forbidden && (forbidden != Thread.current)
                raise ThreadError, "cannot call #allow_blocking_calls with a block outside of the forbidden thread"
            end

            Orocos.no_blocking_calls_in_thread = nil
            begin
                return yield
            ensure
                if forbidden
                    Orocos.no_blocking_calls_in_thread = forbidden
                end
            end
        else
            current_thread = Orocos.no_blocking_calls_in_thread
            Orocos.no_blocking_calls_in_thread = nil
            current_thread
        end
    end

    def self.forbid_blocking_calls
        Orocos.no_blocking_calls_in_thread = Thread.current
    end
end

at_exit do
    if !Orocos.keep_orocos_logfile? && Orocos.orocos_logfile
        FileUtils.rm_f Orocos.orocos_logfile
    end
end

