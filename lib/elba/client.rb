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

      on_elb(load_balancer) do |elb|
        raise InstanceAlreadyAttached if elb.instances.include? instance

        elb.register_instances instance
        elb.instances.include? instance
      end
    end

    def detach(instance)
      on_elb(instance) do |elb|
        elb.deregister_instances instance
        elb.instances.include?(instance) ? nil : elb.id
      end
    end


    private

    def on_elb(name)
      # instances always start with 'i-'
      elb = if name =~ /^i-/
        load_balancers.find { |lb| lb.instances.include? name }
      else
        load_balancers.find { |lb| lb.id =~ /#{name}/ }
      end
      raise LoadBalancerNotFound unless elb
      yield elb if block_given?
    end

  end
end
