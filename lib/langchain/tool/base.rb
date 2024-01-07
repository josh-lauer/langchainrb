# frozen_string_literal: true

require "yard"

module Langchain::Tool
  # = Tools
  #
  # Tools are used by Agents to perform specific tasks. Basically anything is possible with enough code!
  #
  # == Available Tools
  #
  # - {Langchain::Tool::Calculator}: calculate the result of a math expression
  # - {Langchain::Tool::Database}: executes SQL queries
  # - {Langchain::Tool::GoogleSearch}: search on Google (via SerpAPI)
  # - {Langchain::Tool::RubyCodeInterpreter}: runs ruby code
  # - {Langchain::Tool::Weather}: gets current weather data
  # - {Langchain::Tool::Wikipedia}: search on Wikipedia
  #
  # == Usage
  #
  # 1. Pick the tools you'd like to pass to an Agent and install the gems listed under **Gem Requirements**
  #
  #     # For example to use the Calculator, GoogleSearch, and Wikipedia:
  #     gem install eqn
  #     gem install google_search_results
  #     gem install wikipedia-client
  #
  # 2. Set the environment variables listed under **ENV Requirements**
  #
  #     export SERPAPI_API_KEY=paste-your-serpapi-api-key-here
  #
  # 3. Pass the tools when Agent is instantiated.
  #
  #     agent = Langchain::Agent::ReActAgent.new(
  #       llm: Langchain::LLM::OpenAI.new(api_key: "YOUR_API_KEY"), # or other like Cohere, Hugging Face, Google Palm or Replicate
  #       tools: [
  #         Langchain::Tool::GoogleSearch.new(api_key: "YOUR_API_KEY"),
  #         Langchain::Tool::Calculator.new,
  #         Langchain::Tool::Wikipedia.new
  #       ]
  #     )
  #
  # == Adding Tools
  #
  # 1. Create a new file in lib/langchain/tool/your_tool_name.rb
  # 2. Create a class in the file that inherits from {Langchain::Tool::Base}
  # 3. Add `NAME=` and `DESCRIPTION=` constants in your Tool class
  # 4. Implement `execute(input:)` method in your tool class
  # 5. Add your tool to the {file:README.md}
  class Base
    include Langchain::DependencyHelper

    #
    # Returns the NAME constant of the tool
    #
    # @return [String] tool name
    #
    def name
      self.class.const_get(:NAME)
    end

    def self.logger_options
      {
        color: :light_blue
      }
    end

    #
    # Returns the DESCRIPTION constant of the tool
    #
    # @return [String] tool description
    #
    def description
      self.class.const_get(:DESCRIPTION)
    end

    #
    # Sets the DESCRIPTION constant of the tool
    #
    # @param value [String] tool description
    #
    def self.description(value)
      const_set(:DESCRIPTION, value.tr("\n", " ").strip)
    end

    #
    # Instantiates and executes the tool and returns the answer
    #
    # @param input [String] input to the tool
    # @return [String] answer
    #
    def self.execute(input:)
      new.execute(input: input)
    end

    # Returns the tool as an OpenAI tool
    #
    # @return [Hash] tool as an OpenAI tool
    def to_openai_tools
      # Iterate over all the callable methods and convert them to OpenAI format
      self.class.const_get(:CALLABLE_METHODS).map do |method_name|
        params = method(method_name).parameters
        properties = {}
        required_properties = []
        # Expected format: [[:keyreq, :input]]
        params.each do |param|
          properties[param.last] = {
            type: "string", # TODO: Support other types; don't assume string
            description: find_param_yard_tag(method_name: method_name, param: param.last).text
          }
          # If :keyreq (required keyword argument) then add the param name to required_properties
          required_properties << param.last.to_s if param.first == :keyreq
        end

        {
          type: "function",
          function: {
            name: "#{name}-#{method_name}",
            description: find_method_yard_docs(method_name: method_name).docstring,
            parameters: {
              type: "object",
              properties: properties,
              required: required_properties
            }
          }
        }
      end
    end

    def generate_yard_docs!
      YARD.parse("./lib/langchain/tool/#{name}.rb")
    end

    def find_method_yard_docs(method_name:)
      YARD::Registry.all.find { |o| o.title == "#{self.class.name}##{method_name}" }
    end

    def find_param_yard_tag(method_name:, param:)
      find_method_yard_docs(method_name:)
        .tags
        .find { |t| t.tag_name == "param" && t.name == param.to_s }
    end

    #
    # Executes the tool and returns the answer
    #
    # @param input [String] input to the tool
    # @return [String] answer
    # @raise NotImplementedError when not implemented
    def execute(input:)
      raise NotImplementedError, "Your tool must implement the `#execute(input:)` method that returns a string"
    end

    #
    # Validates the list of tools or raises an error
    # @param tools [Array<Langchain::Tool>] list of tools to be used
    #
    # @raise [ArgumentError] If any of the tools are not supported
    #
    def self.validate_tools!(tools:)
      # Check if the tool count is equal to unique tool count
      if tools.count != tools.map(&:name).uniq.count
        raise ArgumentError, "Either tools are not unique or are conflicting with each other"
      end
    end
  end
end
