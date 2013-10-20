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
    end


    desc "list", "Prints the list of available load balancers"
    long_desc <<-DESC
      Prints the list of available load balancers

      With -i | --instances option, prints instances id attached to each load balancer

    DESC
    option :instances, :type => :boolean, :aliases => :i
    def list
      say "#{elbs.size} Load Balancers found:", nil, true
      elbs.map do |elb|
        say " * #{elb.id}"
        elb.instances.map { |i| say "   - #{i}", :green } if options[:instances]
      end
    end


    desc "attach INSTANCE", "Attaches INSTANCE to a load balancer"
    long_desc <<-DESC
      Attaches an INSTANCE to a load balancer.
      Will ask which load balancer to use if more than one available.

      With -t | --to option, specifies which load balancer to attach the instance to

    DESC
    option :to, :type => :string, :aliases => :t
    def attach(instance = nil, load_balancer = options[:to])
      say "You need to provide an instance ID", :red and return unless instance

      begin
        if client.attach instance, load_balancer
          say "#{instance} successfully added to #{load_balancer}", :green
        else
          say "Unable to add #{instance} to #{load_balancer}", :red
        end
      rescue Client::NoLoadBalancerAvailable
        say "No load balancer available", :red and return
      rescue Client::InstanceAlreadyAttached
        say "#{instance} is already attached to #{load_balancer}", :yellow and return
      rescue Client::LoadBalancerNotFound
        say "Load balancer not found" and return
      rescue Client::MultipleLoadBalancersAvailable
        say "More than one Load Balancer available, pick one in the list", :yellow
        print_table elbs_with_index
        choice = ask "Use:", :yellow, :limited_to => elbs_with_index.map(&:last)

        attach instance, choice
      end
    end


    desc "detach INSTANCE", "Detach INSTANCE from a Load Balancer"
    long_desc <<-DESC
      Detaches an INSTANCE from its load balancer.
      Will warn if the instance isn't attached to any ELB

    DESC
    def detach(instance = nil)
      say "You need to provide an instance ID", :red and return unless instance

      begin
        if elb = client.detach instance
          say "#{instance} successfully detached from #{elb}", :green
        else
          say "Unable to detach #{instance}", :red
        end
      rescue Client::LoadBalancerNotFound
        say "#{instance} isn't attached to any known load balancer", :yellow and return
      end
    end

  end
end
