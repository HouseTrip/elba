# encoding: UTF-8

require 'fog'
require 'yaml'

module Elba
  class Client

    DEFAULT_PARAMS = {
      region: 'eu-west-1'
    }

    class NoLoadBalancerAvailable        < StandardError; end
    class MultipleLoadBalancersAvailable < StandardError; end
    class LoadBalancerNotFound           < StandardError; end
    class InstanceAlreadyAttached        < StandardError; end

    def initialize
      @connection = Fog::AWS::ELB.new DEFAULT_PARAMS.merge(parse_config)
    end

    def load_balancers
      @lbs ||= @connection.load_balancers
    end

    def attach(instance = nil, load_balancer = nil)
      raise NoLoadBalancerAvailable if !load_balancer && !load_balancers.any?
      raise MultipleLoadBalancersAvailable if !load_balancer && load_balancers.length > 1

      elb = load_balancers.find { |lb| lb.id =~ /#{load_balancer}/ }
      raise LoadBalancerNotFound unless elb
      raise InstanceAlreadyAttached if elb.instances.include? instance

      elb.register_instances instance
      elb.instances.include? instance
    end

    private

    # Parse config stored in ~/.fog
    # Use :default environment
    def parse_config(env = :default)
      @config ||= YAML.load(File.open File.expand_path('.fog', Dir.home))[env]
    end
  end
end
