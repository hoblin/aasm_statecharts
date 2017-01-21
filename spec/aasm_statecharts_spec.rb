# Unit tests for aasm_statecharts. All checks are performed against
# the representation held by Ruby-Graphviz, not the files written
# to disk; we're dependent on Ruby-Graphviz and dot getting it right.
#
# @author Brendan MacDonell, Ashley Engelund
#

require 'spec_helper'
require 'statechart_helper'

require 'graphviz'

require 'fileutils'

DEFAULT_MODEL = 'two_simple_states'


def good_options
  options = {
      all: false,
      directory: OUT_DIR,
      format: 'png',
      models: [DEFAULT_MODEL]
  }
end


def rm_specout_outfile(outfile = "#{DEFAULT_MODEL}.png")
  fullpath = File.join(OUT_DIR, outfile)
  # FileUtils.rm fullpath if File.exist? fullpath
  # puts "     (cli_spec: removed #{fullpath})"
end


# alias shared example call for readability
RSpec.configure do |c|
  c.alias_it_should_behave_like_to :it_will, 'it will'
end

#- - - - - - - - - - 
RSpec.shared_examples 'use doc directory' do |desc, options|

  it "#{desc}" do
    doc_dir = File.absolute_path(File.join(__dir__, '..', 'doc'))

    FileUtils.rm_r(doc_dir) if Dir.exist? doc_dir

    expect { AASM_StateChart::AASM_StateCharts.new(options).run }.not_to raise_error
    expect(Dir).to exist(doc_dir)
    expect(File).to exist(File.join(doc_dir, "#{DEFAULT_MODEL}.png"))

    FileUtils.rm_r(doc_dir)
  end

end


RSpec.shared_examples 'have attributes = given config' do |item_name, item, options={}|

  item_attribs = item.each_attribute(true) { |a| a }

  options.each do |k, v|
    # GraphViz returns the keys as strings
    it "#{item_name} #{k.to_s}" do
      expect(item_attribs.fetch(k.to_s, nil)).not_to be_nil # will be something like a GraphViz::Types::EscString
      expect(item_attribs.fetch(k.to_s, '').to_s).to eq("\"#{v}\"") #('"Courier New"')
    end

  end

end


RSpec.shared_examples 'have graph attributes = given config' do |item, options={}|

  item_attribs = item.each_attribute { |a| a }

  options.each do |k, v|

    # GraphViz returns the keys as strings

    it "graph #{k.to_s}" do

      expect(item_attribs.fetch(k.to_s, nil)).not_to be_nil # will be something like a GraphViz::Types::EscString
      expect(item_attribs.fetch(k.to_s, '').to_s).to eq("\"#{v}\"") #('"Courier New"')

    end

  end

end


RSpec.shared_examples 'raise error' do |desc, error, options|
  it desc do
    expect { AASM_StateChart::AASM_StateCharts.new(options).run }.to raise_error(error)
  end
end


RSpec.shared_examples 'not raise an error' do |desc, options|
  it desc do
    expect { AASM_StateChart::AASM_StateCharts.new(options).run }.not_to raise_error
  end
end


#- - - - - - - - - - 

def config_from(fn)
  config = {}
  if File.exist? fn
    File.open fn do |cf|
      begin
        config = Psych.safe_load(cf)
      rescue Psych::SyntaxError => ex
        ex.message
      end
    end
  end

  config
end


#- - - - - - - - - -

describe AASM_StateChart::AASM_StateCharts do
  include SpecHelper


  Dir.mkdir(OUT_DIR) unless Dir.exist? OUT_DIR

  include_path = File.join(__dir__, 'fixtures')

  ugly_config_fn = File.join(__dir__, 'fixtures', 'ugly_config_opts.yml')

  ugly_config = config_from ugly_config_fn


  describe 'include path' do

    it_will 'raise error', 'blank path',
            AASM_StateChart::BadPath_Error,
            good_options.merge({path: ''})

    it_will 'raise error', 'nil path',
            AASM_StateChart::BadPath_Error,
            good_options.merge({path: nil})

    it_will 'raise error', 'ill-formed path',
            AASM_StateChart::PathNotLoaded,
            good_options.merge({path: 'blorfy, blorf, blorf? blorf! @blorf'})

    it_will 'raise error', 'path dir does not exist',
            AASM_StateChart::PathNotLoaded,
            good_options.merge({path: 'does/not/exist'})

  end


  describe 'checks model classes' do
    options = good_options


    it 'error if both --all and a model is given' do
      pending # FIXME
    end


    it_will 'raise error', 'model cannot be loaded',
            LoadError,
            good_options.update({models: ['blorfy']}).merge({path: include_path})


    it_will 'raise error', 'warns when given a class that does not have aasm included',
            AASM_StateChart::NoAASM_Error,
            good_options.update({models: ['no_aasm']}).merge({path: include_path})

    it_will 'raise error', 'warns when given a class that has no states defined',
            AASM_StateChart::NoStates_Error,
            good_options.update({models: ['empty_aasm']}).merge({path: include_path})


    it_will 'raise error', 'fails if an invalid file format is given',
            AASM_StateChart::BadFormat_Error,
            good_options.update({models: ['single_state'], format: 'blorf'}).merge({path: include_path})


    it_will 'not raise an error', 'load a list of valid classes',
            good_options.update({models: ['single_state', 'many_states']}).merge({path: include_path})


    it_will 'not raise an error', 'load github',
            good_options.update({models: ['git_hub']}).merge({path: include_path})


    it_will 'not raise an error', 'load pivotal_tracker_feature',
            good_options.update({models: ['pivotal_tracker_feature']}).merge({path: include_path})


    it_will 'raise error', 'one bad class in a list',
            LoadError,
            good_options.update({models: ['single_state', 'blorf']}).merge({path: include_path})


  end


  describe 'output directory' do

    after(:each) { rm_specout_outfile }

    it_will 'use doc directory', 'no directory option provided', good_options.reject! { |k, v| k == :directory }
    it_will 'use doc directory', 'directory = empty string', good_options.update({directory: ''})


    it 'creates the directory if it does not exist' do

      test_dir = File.join(__dir__, 'blorf')
      FileUtils.rm_r(test_dir) if Dir.exist? test_dir

      options = good_options
      options[:directory] = test_dir

      AASM_StateChart::AASM_StateCharts.new(options).run

      expect(Dir).to exist(test_dir)
      FileUtils.rm_r(test_dir)
    end

  end


  describe 'configuration' do
    after(:each) { rm_specout_outfile }

    options = good_options

    it_will 'raise error', 'error: config file option given is non-existent',
            AASM_StateChart::NoConfigFile_Error,
            good_options.update({config_file: 'blorfy.blorf'})

    it_will 'not raise an error', 'no config file exists, use the default options',
            good_options


    describe 'config file graph, node, edge styles ' do

      # TODO simplify! refactor!  shared_context ?

      options[:config_file] = ugly_config_fn
      options[:format] = 'dot'
      options[:path] = include_path

      let!(:graph_out) {
        AASM_StateChart::AASM_StateCharts.new(options).run

        dot_output = "#{OUT_DIR}/#{options[:models].first}.#{options[:format]}"

        GraphViz.parse(dot_output)
      }

      # GraphViz does not have global attributes, so you have to check individual nodes or edges
      let!(:node0) { graph_out.get_node_at_index(0) }
      let(:node_attribs) { node0.each_attribute { |a| a } }

      let!(:edge0) { graph_out.get_edge_at_index(0) }
      let(:edge_attribs) { edge0.each_attribute { |a| a } }

      let(:graph_attribs) { graph_out.each_attribute { |a| a } }

      (ugly_config['graph']['node_style']).each do |k, v|

        it "node #{k.to_s}" do

          expect(node_attribs.fetch(k.to_s, nil)).not_to be_nil # will be something like a GraphViz::Types::EscString
          expect(node_attribs.fetch(k.to_s, '').to_s).to eq("\"#{v}\"") #('"Courier New"')

        end

      end

      (ugly_config['graph']['edge_style']).each do |k, v|

        it "edge #{k.to_s}" do

          expect(edge_attribs.fetch(k.to_s, nil)).not_to be_nil # will be something like a GraphViz::Types::EscString
          expect(edge_attribs.fetch(k.to_s, '').to_s).to eq("\"#{v}\"") #('"Courier New"')

        end

      end

      (ugly_config['graph']['graph_style']).each do |k, v|

        it "graph #{k.to_s}" do

          expect(graph_attribs.fetch(k.to_s, nil)).not_to be_nil # will be something like a GraphViz::Types::EscString
          expect(graph_attribs.fetch(k.to_s, '').to_s).to eq("\"#{v}\"") #('"Courier New"')

        end

      end

      #   it_will 'have graph attributes = given config', graph_out, ugly_config['graph']['graph_style']
      #   it_will 'have attributes = given config', 'node', node0, ugly_config['graph']['node_style']
      #   it_will 'have attributes = given config', 'edge', edge0, ugly_config['graph']['edge_style']


      rm_specout_outfile "#{options[:models].first}.#{options[:format]}"
    end

  end

  describe 'rails class' do

    it 'error if it is not run under Rails config directory' do
      options = good_options
      # FIXME how to run this under a different dir so it can fail?
      expect { AASM_StateChart::AASM_StateCharts.new(options).run }.to raise_error AASM_StateChart::NoRailsConfig_Error
    end


    it 'loads a rails class Purchase' do

      options = {format: 'png', models: ['purchase'], directory: OUT_DIR}
      options[:config_file] = ugly_config_fn
      options[:path] = include_path

      AASM_StateChart::AASM_StateCharts.new(options).run

      expect(File.exist?(File.join(OUT_DIR, 'purchase.png')))
      rm_specout_outfile('purchase.png')
    end

  end
end