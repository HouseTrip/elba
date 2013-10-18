# encoding: UTF-8

require 'bundler/setup'
require 'fog'
require 'yaml'

module Elba
  class Client
    def initialize(env = :default)
      # read from ~/.fog
      config  = YAML.load(File.open(File.expand_path '.fog', Dir.home))[env]
      # connect to AWS
      @client = Fog::AWS::ELB.new default_params.merge(config)
    end

    def load_balancers
      @lbs ||= @client.load_balancers
    end

    private
    def default_params
      {
        region: 'eu-west-1'
      }
    end
  end
end
