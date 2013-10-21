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

    def attach(instance = nil, lb = nil)
      if instance.is_a?(Array)
        instance.each { |i| attach_instance(i, lb) }
      else
        attach_instance(instance, lb)
      end
    end

    def detach(instance = nil)
      elb = load_balancers.find { |elb| elb.instances.include? instance }
      raise LoadBalancerNotFound unless elb

      elb.deregister_instances instance
      elb.instances.include?(instance) ? nil : elb.id
    end

    private

    def attach_instance(instance=nil, lb=nil)
      raise NoLoadBalancerAvailable if !lb && !load_balancers.any?
      raise MultipleLoadBalancersAvailable if !lb && load_balancers.size > 1

      elb = load_balancers.find { |elb| elb.id =~ /#{lb}/ }
      raise LoadBalancerNotFound unless elb
      raise InstanceAlreadyAttached if elb.instances.include? instance

      elb.register_instances instance
      elb.instances.include? instance
    end

    # Parse config stored in ~/.fog
    # Use :default environment
    def parse_config(env = :default)
      @config ||= YAML.load(File.open File.expand_path('.fog', Dir.home))[env]
    end
  end
end
