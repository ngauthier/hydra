require 'cucumber/formatter/ordered_xml_markup'
module Hydra #:nodoc:
  module Listener #:nodoc:
    # Output a textual report at the end of testing
    class CucumberHtmlReport < Hydra::Listener::Abstract
       ## Initialize a new report
      #def testing_begin(files)
      #  @report = { }
      #end
      #
      ## Log the start time of a file
      #def file_begin(file)
      #  @report[file] ||= { }
      #  @report[file]['start'] = Time.now.to_f
      #end
      #
      ## Log the end time of a file and compute the file's testing
      ## duration
      #def file_end(file, output)
      #  @report[file]['end'] = Time.now.to_f
      #  @report[file]['duration'] = @report[file]['end'] - @report[file]['start']
      #end

      # output the report
      def testing_end
        CombineHtml.new.generate


        #@output.close
      end
    end

    class CombineHtml
      def initialize
        @io = File.open('/home/derek/out/report.html', "w")
        @builder = create_builder(@io)
      end

      def generate
        puts "write header"
        before_features

        puts "combine"

        combine_features

        puts "write footer"


        after_features
        @io.flush
        @io.close

        puts "finished"
      end

      def combine_features
        sleep 10
        Dir.glob('/home/derek/out/features/*.html').each do |feature|
          puts "Reading #{feature}"
          File.open( feature, "rb") do |f|
            f.each_line do |line|
              puts line
              @builder << line
            end
          end
        end
      end

      def before_features

        # <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
        @builder.declare!(
          :DOCTYPE,
          :html,
          :PUBLIC,
          '-//W3C//DTD XHTML 1.0 Strict//EN',
          'http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd'
        )

        @builder << '<html xmlns ="http://www.w3.org/1999/xhtml">'
          @builder.head do
          @builder.meta(:content => 'text/html;charset=utf-8')
          @builder.title 'Cucumber'
          inline_css
          inline_js
        end
        @builder << '<body>'
        #@builder << "<!-- Step count #{@step_count}-->"
        @builder << '<div class="cucumber">'
        @builder.div(:id => 'cucumber-header') do
          @builder.div(:id => 'label') do
            @builder.h1('Cucumber Features')
          end
          @builder.div(:id => 'summary') do
            @builder.p('',:id => 'totals')
            @builder.p('',:id => 'duration')
            @builder.div(:id => 'expand-collapse') do
              @builder.p('Expand All', :id => 'expander')
              @builder.p('Collapse All', :id => 'collapser')
            end
          end
        end
      end

      def after_features
        print_stats
        @builder << '</div>'
        @builder << '</body>'
        @builder << '</html>'
      end


      def inline_css
        @builder.style(:type => 'text/css') do
          @builder << File.read(File.dirname(__FILE__) + '/cucumber.css')
        end
      end

      def inline_js
        @builder.script(:type => 'text/javascript') do
          @builder << inline_jquery
          @builder << inline_js_content
        end
      end

      def inline_jquery
        File.read(File.dirname(__FILE__) + '/jquery-min.js')
      end

      def inline_js_content
        <<-EOF

  SCENARIOS = "h3[id^='scenario_']";

  $(document).ready(function() {
    $(SCENARIOS).css('cursor', 'pointer');
    $(SCENARIOS).click(function() {
      $(this).siblings().toggle(250);
    });

    $("#collapser").css('cursor', 'pointer');
    $("#collapser").click(function() {
      $(SCENARIOS).siblings().hide();
    });

    $("#expander").css('cursor', 'pointer');
    $("#expander").click(function() {
      $(SCENARIOS).siblings().show();
    });
  })

  function moveProgressBar(percentDone) {
    $("cucumber-header").css('width', percentDone +"%");
  }
  function makeRed(element_id) {
    $('#'+element_id).css('background', '#C40D0D');
    $('#'+element_id).css('color', '#FFFFFF');
  }
  function makeYellow(element_id) {
    $('#'+element_id).css('background', '#FAF834');
    $('#'+element_id).css('color', '#000000');
  }

        EOF
      end

      def move_progress
      end

      def percent_done
        result = 100.0
        result
      end

      def format_exception(exception)
        (["#{exception.message}"] + exception.backtrace).join("\n")
      end

      def backtrace_line(line)
        line.gsub(/\A([^:]*\.(?:rb|feature|haml)):(\d*).*\z/) do
          if ENV['TM_PROJECT_DIRECTORY']
            "<a href=\"txmt://open?url=file://#{File.expand_path($1)}&line=#{$2}\">#{$1}:#{$2}</a> "
          else
            line
          end
        end
      end

      def print_stats
        #@builder <<  "<script type=\"text/javascript\">document.getElementById('duration').innerHTML = \"Finished in <strong>#{format_duration(features.duration)} seconds</strong>\";</script>"
        #@builder <<  "<script type=\"text/javascript\">document.getElementById('totals').innerHTML = \"#{print_stat_string(features)}\";</script>"
      end

      def print_stat_string(features)
        string = String.new
        string << dump_count(@step_mother.scenarios.length, "scenario")
        scenario_count = print_status_counts{|status| @step_mother.scenarios(status)}
        string << scenario_count if scenario_count
        string << "<br />"
        string << dump_count(@step_mother.steps.length, "step")
        step_count = print_status_counts{|status| @step_mother.steps(status)}
        string << step_count if step_count
      end

      def print_status_counts
        counts = [:failed, :skipped, :undefined, :pending, :passed].map do |status|
          elements = yield status
          elements.any? ? "#{elements.length} #{status.to_s}" : nil
        end.compact
        return " (#{counts.join(', ')})" if counts.any?
      end

      def dump_count(count, what, state=nil)
        [count, state, "#{what}#{count == 1 ? '' : 's'}"].compact.join(" ")
      end

      def create_builder(io)
        Cucumber::Formatter::OrderedXmlMarkup.new(:target => io, :indent => 0)
      end
    end
  end
end
