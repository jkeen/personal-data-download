

# WIP to store some local data after fetch, and not have the scraper
# do the work if we already have it

=begin

  @data_store = DataStore.new(file_path)

  @data_store.save(:profile, :plan_id) do
    // do the work of getting the plan id
    return "plan_xyz"
  end

  plan id will be stored in the data file at

  {
    "profile": {
        "plan_id": "plan_xyz"
    }
  }

  but only if it doesn't exist already. If it does exist,
  the block won't even be called.

=end

require 'json'
require 'hashie'
require 'pry'

module HashExtensions
  refine Hash do
    include Hashie::Extensions::DeepMerge
    # include Hashie::Extensions::IndifferentAccess

    def bury(*args)
      if args.count < 2
        raise ArgumentError.new("2 or more arguments required")
      elsif args.count == 2
        self[args[0]] = args[1]
      else
        arg = args.shift
        self[arg] = {} unless self[arg]

        unless args.empty? # we at the end
          if (!self[arg].is_a?(Hash))
            self[arg]={}
          end
          self[arg].bury(*args)
        end
      end
      self
    end
  end
end

class DataStore
  using HashExtensions

  attr_accessor :data
  def initialize(file_path)
    if File.exist?(file_path)
      # Initialize our new hash, making sure we've got those nice methods
      @data = Hash.new.deep_merge(JSON.parse(File.read(file_path)))
    else
      @data = Hash.new
    end
    @file_path = file_path
  end

  def save(*keys)
    begin
      value = @data.dig(*keys.map(&:to_s))
    rescue
      # we hit a value that wasn't a hash, meaning we stored something there
      value = true
    end

    if value
      # puts "found value #{value}, not saving"
    else
      @data.bury(*keys.map(&:to_s), yield)
      save_file
    end
  end

  def save!(*keys)
    @data.bury(*keys.map(&:to_s), yield)
    save_file
  end

  private

  def save_file
    File.open(@file_path, "w") do |f|
      f.write(JSON.pretty_generate(@data))
    end
  end
end
