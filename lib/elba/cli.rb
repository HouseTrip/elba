require 'thor'
require 'elba'
require 'elba/client'

module Elba
  # The Command Line Interface for {Elba}.
  class Cli < Thor
    include Thor::Actions

    no_tasks do
      # A permanent {Client}
      def client
        @client ||= Client.new
      end

      # Helper method to initialize the load_balancers
      def elbs
        client.load_balancers
      end

      def elbs_with_index
        elbs.map.with_index { |lb,i| [i, lb.id] }
      end

      def find_elb_from_choice choice
        elbs_with_index[choice.to_i].last
      end
    end


    desc "list", "Prints the list of available load balancers"
    long_desc <<-DESC
      Prints the list of available load balancers

      With -i | --instances option, prints instances id attached to each load balancer

    DESC
    option :instances, :type => :boolean, :aliases => :i
    def list with_instances = options[:instances]
      say "#{elbs.size} ELB found:", nil, true
      elbs.map do |elb|
        say " * #{elb.id}"
        elb.instances.map { |i| say "   - #{i}", :green } if with_instances
      end
    end


    desc "attach INSTANCE", "Attaches INSTANCE to a load balancer"
    long_desc <<-DESC
      Attaches an INSTANCE to a load balancer.
      Will ask which load balancer to use if more than one available.

      With -t | --to option, specifies which load balancer to attach the instance to

    DESC
    option :to, :type => :string, :aliases => :t
    def attach(*instances)
      load_balancer = options[:to]
      instances.each { |i| attach_instance(i, load_balancer) }
    end


    desc "detach INSTANCE", "Detach INSTANCE from a Load Balancer"
    long_desc <<-DESC
      Detaches an INSTANCE from its load balancer.
      Will warn if the instance isn't attached to any ELB

    DESC
    def detach instance = nil
      say "You need to provide an instance ID", :red and return unless instance

      elb = client.detach instance
      if elb
        say "#{instance} successfully detached from #{elb}", :green
      else
        say "Unable to detach #{instance}", :red
      end
    rescue Client::LoadBalancerNotFound
      say "#{instance} isn't attached to any known ELB", :yellow and return
    end

    private
    def attach_instance(instance = nil, load_balancer = nil)
      say "You need to provide an instance ID", :red and return unless instance

      if client.attach instance, load_balancer
        say "#{instance} successfully added to #{load_balancer}", :green
      else
        say "Unable to add #{instance} to #{load_balancer}", :red
      end
    rescue Client::NoLoadBalancerAvailable
      say "No ELB available", :red and return
    rescue Client::InstanceAlreadyAttached
      say "#{instance} is already attached to #{load_balancer}", :yellow and return
    rescue Client::LoadBalancerNotFound
      say "ELB not found", :yellow and return
    rescue Client::MultipleLoadBalancersAvailable
      say "More than one ELB available, pick one in the list", :yellow
      print_table elbs_with_index
      choice = ask "Use:", :yellow, :limited_to => elbs_with_index.map(&:first).map(&:to_s)

      attach_instance instance, find_elb_from_choice(choice)
    end

  end
end
