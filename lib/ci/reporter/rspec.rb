require 'ci/reporter/core'

module CI
  module Reporter

    # Wrapper around a <code>RSpec</code> error or failure to be used by the test suite to interpret results.
    class RSpecFailure
      attr_reader :exception

      def initialize(example, formatter)
        @formatter = formatter
        @example = example
        if @example.respond_to?(:execution_result)
          @exception = @example.execution_result[:exception] || @example.execution_result[:exception_encountered]
        else
          @exception = @example.metadata[:execution_result][:exception]
        end
      end

      def name
        @exception.class.name
      end

      def message
        @exception.message
      end

      def failure?
        exception.is_a?(::RSpec::Expectations::ExpectationNotMetError)
      end

      def error?
        !failure?
      end

      def location
        output = []
        output.push "#{exception.class.name << ":"}" unless exception.class.name =~ /RSpec/
        output.push @exception.message

        backtrace_formatter = ::RSpec::Core::BacktraceFormatter.new
        backtrace = backtrace_formatter.format_backtrace(@exception.backtrace)

        backtrace.each do |backtrace_info|
          backtrace_info.lines.each do |line|
            output.push "     #{line}"
          end
        end
        output.join "\n"
      end
    end

    class RSpecFormatter < ::RSpec::Core::Formatters::ProgressFormatter
      attr_accessor :suite, :report_manager, :output
      if ::RSpec::Core::Formatters.respond_to?(:register)
       ::RSpec::Core::Formatters.register self, :example_group_started,
                                         :example_started, :example_passed, :example_failed,
                                         :example_pending, :dump_summary
     end

      def initialize(output)
        @output = output
        @report_manager = ReportManager.new("spec")
      end

      def example_group_started(notification)
        new_suite(description_for(notification.group))
      end

      def example_started(notification)
        spec = TestCase.new
        @suite.testcases << spec
        spec.start
      end

      def example_passed(notification)
        spec = @suite.testcases.last
        spec.finish
        spec.name = description_for(notification.example)
      end


      def example_failed(notification, *rest)
        output.puts notification.example.execution_result
        #
        # In case we fail in before(:all)
        example_started(notification) if @suite.testcases.empty?
        failure = RSpecFailure.new(notification.example, self)

        spec = @suite.testcases.last
        spec.finish
        spec.name = description_for(notification.example)
        spec.failures << failure
      end


      def dump_summary(summary)
        write_report
      end

      def write_report
        suite.finish
        report_manager.write_report(suite)
      end

      def new_suite(name)
        write_report if @suite
        @suite = TestSuite.new name
        @suite.start
      end

      private
      def description_for(name_or_example)
        if name_or_example.respond_to?(:full_description)
          name_or_example.full_description
        elsif name_or_example.respond_to?(:metadata)
          name_or_example.metadata[:example_group][:full_description]
        elsif name_or_example.respond_to?(:description)
          name_or_example.description
        else
          "UNKNOWN"
        end
      end
    end

    RSpec = RSpecFormatter

    class RSpecDoc < RSpec
      def initialize(*args)
        @formatter = RSpecFormatters::DocFormatter.new(*args)
        super
      end
    end

    class RSpecBase < RSpec
      def initialize(*args)
        @formatter = RSpecFormatters::BaseFormatter.new(*args)
        super
      end
    end
  end
end
