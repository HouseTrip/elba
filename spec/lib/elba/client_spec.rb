require 'spec_helper'
require 'elba/client'
require 'support/mocks'

describe Elba::Client do
  include Elba::Mocks

  let(:elb) do
    test_elb_connection.tap do |c|
      # creates an ELB if none have been created yet
      c.create_load_balancer([test_region], 'elba-test') if c.load_balancers.empty?
    end.load_balancers.last
  end

  let(:instance) { test_ec2_connection.servers.create region: test_region }

  subject { described_class.new test_elb_connection }

  describe 'interface' do
    it 'responds to attach' do
      subject.should.respond_to? :attach
    end

    it 'responds to detach' do
      subject.should.respond_to? :detach
    end
  end

  describe '#attach' do
    context 'no load balancer specified' do
      it 'raises an error if no load balancers are available' do
        subject.stub load_balancers: []
        expect { subject.attach(nil, nil) }.to raise_error described_class::NoLoadBalancerAvailable
      end

      it 'raises an error if more than 1 load balancers available' do
        subject.stub load_balancers: [double, double]
        expect { subject.attach(nil, nil) }.to raise_error described_class::MultipleLoadBalancersAvailable
      end
    end

    context 'load balancer specified' do
      it 'raises an error if the load balancer can\'t be fond' do
        expect {
          subject.attach(instance, 'unknown')
        }.to raise_error described_class::LoadBalancerNotFound
      end

      it 'raises an error if instance is already attached to the load balancer' do
        # makes sure the instance is ready before playing with it!
        subject.attach(instance.id, elb.id)

        expect {
          subject.attach(instance.id, elb.id)
        }.to raise_error described_class::InstanceAlreadyAttached
      end

      it 'returns true if instance has been successfuly added' do
        subject.attach(instance.id, elb.id).should be_true
      end

      it 'returns false if instance can\'t be added' do
        # mock failure of register_instances
        elb.class.any_instance.should_receive(:register_instances).and_raise(RuntimeError)

        expect { subject.attach(instance.id, elb.id) }.to raise_error
      end
    end
  end

  describe '#detach' do
    it 'raises an error if the instance is not attached to any elb'  do
      expect {
        subject.detach instance.id
      }.to raise_error described_class::LoadBalancerNotFound
    end

    it 'returns the elb on success' do
      subject.attach(instance.id, elb.id)

      subject.detach(instance.id).should be_a(Fog::AWS::ELB::LoadBalancer)
    end

    it 'returns nil if instance can\'t be removed from its load balancer' do
      subject.attach(instance.id, elb.id)
      elb.class.any_instance.should_receive(:deregister_instances).and_raise(RuntimeError)

      expect { subject.detach(instance.id) }.to raise_error
    end
  end
end
