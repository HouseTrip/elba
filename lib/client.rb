# encoding: UTF-8

require 'bundler/setup'
require 'fog'
require 'yaml'
require 'forwardable'

module Elba
  class Client

    extend Forwardable

    def_delegators :@client, :load_balancers, :attach_instances, :detach_instances

    def initialize(env = :default)
      # read from ~/.fog
      config  = YAML.load(File.open(File.expand_path '.fog', Dir.home))[env]
      # connect to AWS
      @client = Fog::AWS::ELB.new default_params.merge(config)
    end

    private
    def default_params
      {
        region: 'eu-west-1'
      }
    end
  end
end
