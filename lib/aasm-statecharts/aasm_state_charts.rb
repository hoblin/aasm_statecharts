require 'graphviz'
require 'active_record'
require 'rails'

require_relative 'transition_table'
require_relative 'chart_renderer'

require 'pp'

# Library module than handles translating AASM state machines to statechart
# diagrams.
#
# Usage is simple. First, create an instance of AASM_StateChart::Renderer, passing
# in the class that has the AASM state machine that you would like to generate
# the diagram of. Then call #save with the filename to save the diagram to, as well
# as the format to save in. This must be one of the formats specified in
# GraphViz::Constants::FORMATS.
#
# For example, to render the state machine associated with a class named ModelClass,
# you would do the following:
#   
#   renderer = AASM_StateChart::Renderer.new(ModelClass)
#   renderer.save(filename, format: 'png')
#
# @author Brendan MacDonell and Ashley Engelund
#
# @see http://www.graphviz.org/Documentation.php for style and attribute documentation
#------------------------------------------------------------


module AASM_StateChart

  # TODO title and subtitle: use HtmlString

  class AASM_StateCharts

    ALL_ATTRIBS_TITLE = 'All attribute groups'
    GRAPH_ATTRIBS_TITLE = 'Graph attributes:'
    NODE_ATTRIBS_TITLE = 'Node attributes:'
    GV_TYPES_ATTRIBS_TITLE = 'GraphViz types:'
    EDGE_ATTRIBS_TITLE = 'Edge attributes:'
    COLORS_ATTRIBS_TITLE = 'Colors:'
    PROGRAMS_ATTRIBS_TITLE = 'Programs:'
    GRAPHTYPE_ATTRIBS_TITLE = 'Graph Types:'
    FORMAT_ATTRIBS_TITLE = 'File Formats:'


    def initialize(options={})

      @options = options
      puts "\n\n@options: #{@options.inspect}"

      @include_paths = get_included_paths options[:path] if options.has_key?(:path) # don't use fetch because nil is meaningful (we need to raise an error)


      if options[:models].empty? && !options[:dump_configs] && !options[:all]
      #if !options[:all] && options[:models].empty?  # should never happen; opts parsing should catch it
        raise_error AASM_NoModels, "You must specify a model to diagram or else use the --all option."
      end

      @output_dir = get_output_dir options.fetch(:directory, '')

      #load_rails

      @models = get_models options[:all], options[:models]

      @show_transition_table = options[:transition_table]

      @format = verify_file_format options[:format]

      @config_options = Hash.new.merge(load_config_file(options.fetch(:config_file, '')))


    end


    def run

      if @options.fetch(:dump_configs, false)
        dump_attribs @options[:dump_configs]
      end


      unless @models.blank?
        @models.each do |m|
          klass = Module.const_get m

          name = klass.name.underscore

          if !(klass.respond_to? :aasm)
            raise NoAASM_Error, "ERROR: #{klass.name} does not include AASM.  No diagram generated."

          else

            if klass.aasm.states.empty?
              raise NoStates_Error, "ERROR: No states found for #{klass.name}!  No diagram generated"
            else

              renderer = AASM_StateChart::Chart_Renderer.new(klass, @show_transition_table, @config_options)

              filename = File.join(@output_dir, "#{name}.#{@format}")

              renderer.save(filename, format: @format)

              puts " * diagrammed #{name} and saved to #{filename}"

            end

          end


        end

      end

    end


    # - - - - - - - -
    private

    def dump_attribs(option)

      gv_colors = {'named colors': GraphViz::Utils::Colors::COLORS}
      gv_formats = {'output file formats': GraphViz::Constants::FORMATS}
      gv_programs = {'programs to process dot file': GraphViz::Constants::PROGRAMS}
      gv_graphtype = {'graph types': GraphViz::Constants::GRAPHTYPE}

      # @url http://www.graphviz.org/content/arrow-shapes
      gv_arrowshapes = {'Shapes': ['box', 'crow', 'curve', 'icurve', 'diamond', 'dot', 'inv', 'none', 'normal', 'tee', 'vee'],
                        'modifiers': ['o', 'l', 'r']}

      # @url http://www.graphviz.org/content/color-names
      gv_color_schemes = {}

      # TODO friendlize: put into the format for config.yml.  Explain the keys and some values

      # node shapes and info @url http://www.graphviz.org/content/node-shapes

      gv_types_info = {
          EscString: 'a string',
          GvDouble: 'decimal point number (double)',
          GvBool: 'boolean (true or false)',
          Color: "one of the accepted color names, or the hex code WITHOUT the '#'",
          ArrowType: "one of the arrow shapes with optional modifiers",
          Rect: "???",
          SplineType: "???",
          LblString: "??? label string?  <gv>STRING</gv>",
          HtmlString: " a string surrounded by '<' and '>' (prepended with '<' and appended with '>')"
      }


      config_hash = case option

                      when :all
                        title_with_hash ALL_ATTRIBS_TITLE,
                                        graphviz_options_for(/G|S|X/)
                                            .merge(graphviz_options_for(/N/))
                                            .merge(graphviz_options_for(/E/))
                                            .merge(gv_colors)
                                            .merge({'Formats': gv_formats})
                                            .merge({'Programs': gv_programs})
                                            .merge({'Graph Types': gv_graphtype})

                      when :graph
                        title_with_hash GRAPH_ATTRIBS_TITLE, graphviz_options_for(/G|S|X/)

                      when :nodes
                        title_with_hash NODE_ATTRIBS_TITLE, graphviz_options_for(/N/)

                      when :edges
                        title_with_hash EDGE_ATTRIBS_TITLE, graphviz_options_for(/E/)

                      when :colors
                        title_with_hash COLORS_ATTRIBS_TITLE, gv_colors

                      when :formats
                        title_with_hash FORMAT_ATTRIBS_TITLE, gv_formats # Array

                      when :programs
                        title_with_hash PROGRAMS_ATTRIBS_TITLE, gv_programs # Array

                      when :graphtype
                        title_with_hash GRAPHTYPE_ATTRIBS_TITLE, gv_graphtype # Array
                      else
                        {}
                    end

      puts config_hash.pretty_inspect
      config_hash
    end


    def graphviz_options_for(regex)
      GraphViz::Constants::getAttrsFor(regex)
    end


    def title_with_hash(title, hash)
      {'Title': title, 'values': hash}
    end


    def get_included_paths(options_path)

      full_paths = []
      if options_path.blank?
        raise BadPath_Error, "\n\nERROR: Could not read #{options_path}.  Please check it carefully. Use '#{File::PATH_SEPARATOR}' to separate directories."

      elsif (paths = options_path.split File::PATH_SEPARATOR).count == 0
        raise BadPath_Error, "\n\nERROR: Could not read #{options_path}.  Please check it carefully. Use '#{File::PATH_SEPARATOR}' to separate directories."
      end

      paths.each do |path|
        fullpath = File.absolute_path (path)

        if Dir.exist? fullpath
          $LOAD_PATH.unshift(fullpath) # add to the start of $LOAD_PATH
          full_paths << fullpath
        else
          raise PathNotLoaded_Error, "\n\nERROR: Could not load path #{path}."
        end

      end

      full_paths

    end


    def get_output_dir(options_dir)

      default_dir = 'doc' #'./doc'

      out_dir = options_dir == '' ? default_dir : options_dir

      Dir.mkdir(out_dir) unless Dir.exist? out_dir
      out_dir
    end


    #  used to get all subclasses of ActiveRecord.  Is there a way to get them without loading all of rails?
    def load_rails

      unless File.exist? './config/environment.rb'
        script_name = File.basename $PROGRAM_NAME
        raise NoRailsConfig_Error, "Error: unable to find ./config/environment.rb.\n Please run #{script_name} from the root of your Rails application."
      end

      require './config/environment'
    end


    def get_models(all_option, models)

      model_classes = []
      # TODO not going to worry about the all_option right now
      if all_option

      else

        models.each do |model|
          puts "\n model: #{model}\n"
          begin
            require model
          rescue
            @include_paths.each do |fullpath|
              begin
                require_relative File.join(fullpath, model)
              end
              # TODO how to ignore any error raised?
            end

            raise ModelNotLoaded_Error, "\n\nERROR: Could not load #{model} (Looked in #{@include_paths} and\n $LOAD_PATH: #{$LOAD_PATH.inspect})."
          end

          model_classes << model.camelize
        end
      end

      model_classes

    end


    def load_models(load_all, models_named)

      @models = load_all ? collect_all_models : load_models_named(models_named)

    end


    def load_models_named(model_names)
      model_names.map { |model_name| model_name.camelize.constantize }
    end


    def collect_all_models

      Rails::Application.subclasses.first.eager_load!
      ActiveRecord::Base.descendants.select { |klass| klass.respond_to? :aasm }

    end


    def verify_file_format (format_extension)
      valid_formats = GraphViz::Constants::FORMATS
      unless valid_formats.include? format_extension
        valid_list = valid_formats.join ', '
        raise BadFormat_Error, "\n\nERROR: File format #{format_extension} is not a valid format.\n   These are the valid formats:\n  #{valid_list}"
      end

      format_extension
    end


    def load_config_file (config_fn)
      parsed_config = {}

      unless config_fn == ''
        if File.exist? config_fn
          File.open config_fn do |cf|
            begin
              parsed_config = Psych.safe_load(cf)
            rescue Psych::SyntaxError => ex
              ex.message
            end
          end
        else
          raise NoConfigFile_Error, "The config file #{config_fn} doesn't exist."
        end

      end

      # need to flatten these 1 level to get them into what GraphViz expect
      parsed_opts = {}
      parsed_config.each do |k, v|
        parsed_config[k].each do |k2, v2|
          parsed_opts[k2] = v2
        end
      end
      symbolize_the_keys parsed_opts
    end


    # GraphViz expects keys to be symbols, but it's only safe (and user friendly) to have
    # keys as strings in a config file
    def symbolize_the_keys(hash)

      hash.each_with_object({}) { |(k, v), h| h[k.to_sym] = v.is_a?(Hash) ? symbolize_the_keys(v) : v }
    end


  end #class

end # module
