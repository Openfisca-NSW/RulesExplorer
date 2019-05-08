# frozen_string_literal: true

class ParametersFetchService
  def self.git_clone_folder
    "./tmp/#{ENV['RAILS_ENV']}-openfisca-aotearoa"
  end

  def self.yaml_tests_folder
    "#{git_clone_folder}/openfisca_aotearoa/parameters/"
  end

  def self.fetch_all
    found_parameters = [] # Keep a running list of parameters we found

    Find.find(yaml_tests_folder).each do |filename|
      next unless File.extname(filename) == '.yaml'

      Rails.logger.debug(filename)

      # https://github.com/ruby/psych/issues/262
      parameters_list = YAML.load(File.read(filename)) # rubocop:disable Security/YAMLLoad
      parameter_names = parameters_list.map { |s| s }
      found_parameters += parameter_names
      Rails.logger.debug(parameter_names)
      find_all_duplicates(parameter_names)
      find_or_create_parameter(parameters_list)
    end

    remove_stale_parameters(parameter_names: found_parameters)
  end

  def self.find_or_create_parameter(parameter_name:, parameter_attributes: {})
    parameter = Parameter.find_or_initialize_by(name: parameter_name)
    parameter.update(parameter_attributes)

    fetch(parameter)
  end

  def self.remove_stale_parameters(parameter_names)
    puts parameter_names
    Parameter
      .where
      .not(description: parameter_names)
      .delete_all
  end

  def self.find_all_duplicates(array)
    map = {}
    dup = []
    array.each do |v|
      map[v] = (map[v] || 0) + 1

      dup << v if map[v] == 2
    end
    raise StandardError.new("These parameters have duplicate names: #{dup} !!!!!") if dup[0]
  end

  def self.find_or_create_parameter(yaml_parameter)
    parameter_name = yaml_parameter['description']
    raise if parameter_name.blank?

    parameter = Parameter.find_or_initialize_by(description: parameter_name)

    ActiveRecord::Base.transaction do
      parameter.description = yaml_parameter['description']
      parameter.href = yaml_parameter['reference']
      parameter.brackets = 'brackets'
      parameter.save!
      parameter.parse_values!
      parameter
    end
  end
end
