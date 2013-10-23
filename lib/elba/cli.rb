# encoding: UTF-8

require 'thor'
require 'yaml'
require 'fog'

require 'elba/client'

module Elba
  # The Command Line Interface for {Elba}.
  class Cli < Thor
    include Thor::Actions

    no_tasks do
      # Parse config stored in ~/.fog
      # Use :default environment
      def config(env = :default)
        @config ||= {}.tap do |c|
          c.merge! YAML.load(File.open File.expand_path('.fog', Dir.home))[env]
          c.merge! region: 'eu-west-1'
        end
      end

      # A permanent access to a Client
      def client
        @client ||= Client.new Fog::AWS::ELB.new(config)
      end

      # Helper method to store the ELBs
      def elbs
        client.load_balancers
      end

      def elbs_with_index
        elbs.map.with_index { |elb, i| [i, elb.id] }
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
    def list(with_instances = options[:instances])
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
      elb = options[:to]
      say "You must specify which ELB to use when attaching mulitple instances" unless elb

      instances.map do |instance|
        attach_instance(
          instance,
          elb,
          on_success: ->(instance, lb) {
            say "#{instance} successfully added to #{lb}", :green
          },
          on_failure: ->(instance, lb) {
            say "Unable to add #{instance} to #{load_balancer}", :red
          }
        )
      end
    end


    desc "detach INSTANCE", "Detach INSTANCE from a Load Balancer"
    long_desc <<-DESC
      Detaches an INSTANCE from its load balancer.
      Will warn if the instance isn't attached to any ELB

    DESC
    def detach(*instances)
      instances.map do |instance|
        detach_instance(
          instance,
          on_success: ->(instance, elb) {
            say("#{instance} successfully detached from #{elb}", :green)
          },
          on_failure: ->(instance) {
            say("Unable to detach #{instance}", :red)
          }
        )
      end
    end

    private
    def attach_instance(instance, elb, options = {})
      say "You need to provide an instance ID", :red and return unless instance

      on_success    = options.fetch(:on_success)
      on_failure    = options.fetch(:on_failure)

      if client.attach(instance, elb)
        on_success.call(instance, elb)
      else
        on_failure.call(instance, elb)
      end

    rescue Client::NoLoadBalancerAvailable
      say "No ELB available", :red and return
    rescue Client::InstanceAlreadyAttached
      say "#{instance} is already attached to #{elb}", :yellow and return
    rescue Client::LoadBalancerNotFound
      say "ELB not found", :yellow and return
    rescue Client::MultipleLoadBalancersAvailable
      say "More than one ELB available, pick one in the list", :yellow
      print_table elbs_with_index
      choice = ask "Use:", :yellow, :limited_to => elbs_with_index.map(&:first).map(&:to_s)

      attach_instance instance, find_elb_from_choice(choice)
    end

    def detach_instance(instance, options = {})
      say "You need to provide an instance ID", :red and return unless instance
      on_success = options.fetch(:on_success)
      on_failure = options.fetch(:on_failure)

      success = client.detach(instance)
      if success
        on_success.call(instance, success.id)
      else
        on_failure.call(instance)
      end
    rescue Client::LoadBalancerNotFound
      say "#{instance} isn't attached to any known ELB", :yellow and return
    end

  end
end
