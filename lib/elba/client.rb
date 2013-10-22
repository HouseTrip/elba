# encoding: UTF-8

module Elba
  class Client

    class NoLoadBalancerAvailable        < StandardError; end
    class MultipleLoadBalancersAvailable < StandardError; end
    class LoadBalancerNotFound           < StandardError; end
    class InstanceAlreadyAttached        < StandardError; end

    attr_reader :connection

    def initialize(connection = nil)
      raise ArgumentError.new "Missing connection" unless connection
      @connection = connection
    end

    def load_balancers
      @lbs ||= connection.load_balancers
    end

    def attach(instance, load_balancer)
      raise NoLoadBalancerAvailable if !load_balancer && !load_balancers.any?
      raise MultipleLoadBalancersAvailable if !load_balancer && load_balancers.size > 1

      elb = load_balancers.find { |elb| elb.id =~ /#{load_balancer}/ }
      raise LoadBalancerNotFound unless elb
      raise InstanceAlreadyAttached if elb.instances.include? instance

      elb.register_instances instance
      elb.instances.include? instance
    end

    def detach(instance)
      elb = load_balancers.find { |elb| elb.instances.include? instance }
      raise LoadBalancerNotFound unless elb

      elb.deregister_instances instance
      elb.instances.include?(instance) ? nil : elb.id
    end
  end
end
