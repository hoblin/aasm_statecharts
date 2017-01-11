require 'simplecov'

SimpleCov.start do
  add_filter "/spec/"
end

require 'rspec'

require 'aasm'
require 'active_record'

require_relative '../lib/aasm_statechart'

require_relative '../spec/fixtures/no_aasm'
require_relative '../spec/fixtures/empty_aasm'
require_relative '../spec/fixtures/single_state'
require_relative '../spec/fixtures/many_states'