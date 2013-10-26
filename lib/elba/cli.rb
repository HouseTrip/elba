# encoding: UTF-8

require 'thor'
require 'yaml'
require 'elba/client'

module Elba
  # The Command Line Interface for Elba.
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
        @client ||= Client.new config
      end

      # Helper method to store the ELBs
      def elbs
        @elbs ||= client.load_balancers
      end

      def elbs_names
        elbs.map(&:id)
      end

      def elbs_with_index
        elbs.map.with_index { |elb, i| [i, elb.id] }
      end

      def from_choice(options = {})
        name = options.fetch(:name) { elbs_with_index[options[:choice].to_i].last }
        elbs.find { |elb| elb.id == name }
      end

      def for_choice
        elbs_with_index.map(&:first).map(&:to_s)
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
      name = options[:to]

      elb = if name
        from_choice(name: name)
      else
        if elbs.size == 1
          say "Using default load balancer: #{elbs[0].id}", :yellow
          elbs[0]
        elsif elbs.size > 1
          say("You must specify an ELB", :yellow)
          print_table elbs_with_index
          choice = ask "Use:", :yellow, limited_to: for_choice
          from_choice(choice: choice)
        else
          say("No load balancer available", :red) and return
        end
      end

      instances.map do |instance|
        client.attach(instance, elb,
          on_success: -> {
            say "#{instance} successfully added to #{elb.id}", :green
          },
          on_failure: ->(reason) {
            say "Unable to attach #{instance} to #{elb.id}", :red
            say "Reason: #{reason}", :yellow
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
      elbs.select { |elb| (elb.instances & instances).any? }.tap do |target|
        say("Unable to find an elb for #{instances.join(', ')}", :yellow) and return if target.empty?

        target.map do |elb|
          client.detach(instances, elb,
            on_success: -> {
              say "#{instances.join(', ')} successfully detached from #{elb.id}", :green
            },
            on_failure: ->(reason) {
              say "Unable to detach #{instances.join(', ')} from #{elb.id}", :red
              say "Reason: #{reason}", :yellow
            }
          )
        end
      end
    end
  end
end
