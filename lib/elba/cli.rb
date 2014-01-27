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

      def servers
        @servers ||= client.servers
      end

      def elbs_names
        elbs.map(&:id)
      end

      def elbs_with_index
        elbs.map.with_index { |elb, i| [i, elb.id] }
      end

      def find_elb(options = {})
        name = options.fetch(:name) { elbs_with_index[options[:choice]].last }
        elbs.find { |elb| elb.id == name }
      end

      def for_choice
        elbs_with_index.map(&:first).map(&:to_s)
      end

      def success(message = "")
        say message, :green
      end

      def warn(message = "")
        say message, :yellow
      end

      def error(message = "")
        say message, :red
      end
    end


    desc "list", "Prints the list of available load balancers"
    option :instances, type: :boolean, aliases: :i, desc: "Prints instances id attached to each load balancer"
    option :format, type: :string, aliases: :f, desc: "Format the output: instances"
    long_desc <<-EOS
      `elba list` will print out the list of available ELB
      You can optionally specify the format of the output:
      - instances: will display the instance ids attached to each ELB
      - full: will display the full information about each instance (id, public dns, availability zone)
    EOS
    def list(format = options[:format])
      if elbs.size > 0
        say "#{elbs.size} ELB found:"
        elbs.map do |elb|
          say " * #{elb.id}"
          output = servers.select {|srv| elb.instances.include?(srv.id) }.map.with_index do |srv, i|
            [i, srv.id, srv.tags["Name"], srv.dns_name]
            # if srv.state == "running"
            #   success(msg)
            # else
            #   error(msg)
            # end
          end
          print_table output
        end
      else
        warn "No ELB available"
      end
    end


    desc "attach INSTANCES", "Attaches given instances ids to a load balancer"
    option :to, type: :string, aliases: :t, desc: "Specifies which load balancer to use"
    def attach(*instances)
      elb = if options[:to]
        find_elb(name: options[:to])
      else
        case
        when elbs.size == 0
          error "No load balancer available"
          return
        when elbs.size == 1
          warn "Using default load balancer: #{elbs.first.id}"
          elbs.first
        when elbs.size > 1
          warn "You must specify an ELB"
          print_table elbs_with_index
          choice = ask("Use:", :yellow, limited_to: for_choice).to_i
          find_elb(choice: choice)
        end
      end

      instances.map do |instance|
        client.attach(instance, elb,
          on_success: -> { success "#{instance} successfully attached to #{elb.id}" },
          on_failure: ->(reason) {
            error "Unable to attach #{instance} to #{elb.id}"
            warn "Reason: #{reason}"
          }
        )
      end
    end


    desc "detach INSTANCES", "Detach INSTANCES from their Load Balancer"
    def detach(*instances)
      elbs.reload.select { |elb| (elb.instances & instances).any? }.tap do |lbs|
        warn "Unable to find any ELB to detach #{instances.join(', ')}" if lbs.empty?
        lbs.map do |elb|
          target_instances = elb.instances & instances
          client.detach(target_instances, elb,
            on_success: -> { success "#{target_instances.join(', ')} successfully detached from #{elb.id}" },
            on_failure: ->(reason) {
              error "Unable to detach #{target_instances.join(', ')} from #{elb.id}"
              warn "Reason: #{reason}"
            }
          )
        end
      end
    end
  end
end
