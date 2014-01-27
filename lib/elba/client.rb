# encoding: UTF-8

require 'fog'
require 'forwardable'

module Elba
  class Client
    extend Forwardable
    attr_reader :connection, :ec2

    def initialize(config = {})
      raise "Missing AWS credentials" unless valid_config?(config)

      @connection = Fog::AWS::ELB.new(config)
      @ec2        = Fog::Compute::AWS.new(config)
    end

    def_delegator :connection, :load_balancers
    def_delegator :ec2, :servers

    def attach(instance, load_balancer, callbacks = {})
      load_balancer = load_balancer.register_instances instance
      callbacks[:on_success].call if callbacks[:on_success]
    rescue Exception => ex
      callbacks[:on_failure].call(ex) if callbacks[:on_failure]
    end

    def detach(instances, load_balancer, callbacks = {})
      load_balancer = load_balancer.deregister_instances instances
      callbacks[:on_success].call if callbacks[:on_success]
    rescue Exception => ex
      callbacks[:on_failure].call(ex) if callbacks[:on_failure]
    end


    private

    def valid_config?(config)
      (config.keys & [:aws_secret_access_key, :aws_access_key_id, :region]).any?
    end
  end
end
