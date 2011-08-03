require 'cucumber/formatter/ordered_xml_markup'
module Hydra #:nodoc:
  module Listener #:nodoc:
    # Output a textual report at the end of testing
    class CucumberHtmlReport < Hydra::Listener::Abstract

      def testing_end
        CombineHtml.new.generate
      end
    end

    class CombineHtml
      def initialize(output_file = nil)
        @results_path = File.join(Dir.pwd, 'results')
        output_file = File.join(@results_path, 'html/index.html') if output_file.nil?
        @io = File.open(output_file, "w")
        @builder = create_builder(@io)
      end

      def generate
        before_features
        combine_features
        after_features
        @io.flush
        @io.close


        FileUtils.rm_r File.join(@results_path, 'features')
      end

      def wait_for_two_seconds_while_files_are_written
        sleep 2
      end

      def combine_features
        wait_for_two_seconds_while_files_are_written
        Dir.glob(File.join(@results_path, 'features/*.html')).sort.each do |feature|
          File.open( feature, "rb") do |f|
            f.each_line do |line|
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


      def create_builder(io)
        Cucumber::Formatter::OrderedXmlMarkup.new(:target => io, :indent => 0)
      end
    end
  end
end
