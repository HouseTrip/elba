# encoding: UTF-8

module Elba
  class Client

    class NoLoadBalancerAvailable        < StandardError; end
    class MultipleLoadBalancersAvailable < StandardError; end
    class LoadBalancerNotFound           < StandardError; end
    class InstanceAlreadyAttached        < StandardError; end

    attr_reader :connection

    # instances always start with i-
    INSTANCE_MATCHER = /^(i-)/

    def initialize(connection = nil)
      raise ArgumentError.new "Missing connection" unless connection
      @connection = connection
    end

    def load_balancers
      @lbs ||= connection.load_balancers
    end

    def attach(instance, load_balancer)
      load_balancer || any_load_balancers?

      on_elb load_balancer do |elb|
        raise InstanceAlreadyAttached if elb.instances.include? instance

        elb.register_instances instance
        elb.instances.include? instance
      end
    end

    def detach(instance)
      on_elb instance do |elb|
        elb.deregister_instances instance
        elb.instances.include?(instance) ? nil : elb.id
      end
    end


    private

    def any_load_balancers?
      raise NoLoadBalancerAvailable unless load_balancers.any?
      raise MultipleLoadBalancersAvailable if load_balancers.size > 1
    end

    def on_elb(object)
      elb = find_load_balancer(object)
      raise LoadBalancerNotFound unless elb

      yield elb if block_given?
    end

    def find_load_balancer(object)
      if is_load_balancer? object
        load_balancers.find { |lb| lb.id =~ /#{object}/ }
      else
        load_balancers.find { |lb| lb.instances.include? object }
      end
    end

    def is_load_balancer?(object)
      # negate matches an instance
      !!!(INSTANCE_MATCHER =~ object)
    end

  end
end
