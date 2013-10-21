require 'spec_helper'
require 'elba/client'

describe Elba::Client do
  describe 'interface' do
    it 'responds to attach' do
      subject.should.respond_to? :attach
    end

    it 'responds to detach' do
      subject.should.respond_to? :detach
    end
  end

  let(:instance) { 'x-00000000' }

  describe '#attach' do
    context 'no load balancer specified' do

      it 'raises an error if no load balancers are available' do
        subject.stub :load_balancers => []
        expect { subject.attach(nil, nil) }.to raise_error described_class::NoLoadBalancerAvailable
      end

      it 'raises an error if more than 1 load balancers available' do
        subject.stub :load_balancers => [double, double]
        expect { subject.attach(nil, nil) }.to raise_error described_class::MultipleLoadBalancersAvailable
      end

    end

    context 'load balancer specified' do
      let(:elb) { double :id => 'elba-test', :instances => [] }

      before :each do
        subject.stub :load_balancers => [elb]
      end

      it 'raises an error if the load balancer can\'t be find' do
        expect {
          subject.attach(instance, 'unknown')
        }.to raise_error described_class::LoadBalancerNotFound
      end

      it 'raises an error if instance is already attached to the load balancer' do
        elb.stub :instances => [instance]
        expect {
          subject.attach(instance, elb.id)
        }.to raise_error described_class::InstanceAlreadyAttached
      end

      it 'returns true if instance has been successfuly added' do
        elb.stub :register_instances do |instance|
          elb.instances << instance
        end

        subject.attach(instance, elb.id).should be_true
      end

      it 'returns false if instance can\'t be added' do
        elb.stub :register_instances

        subject.attach(instance, elb.id).should be_false
      end
    end
  end

  describe '#detach' do
    let(:elb) { double :id => 'elba-test', :instances => [instance] }

    before :each do
      subject.stub :load_balancers => [elb]
    end

    it 'raises an error if it can\'t find a load balancer for the isntance' do
      subject.stub :load_balancers => []

      expect {
        subject.detach instance
      }.to raise_error described_class::LoadBalancerNotFound
    end

    it 'returns the elb name if instance has been removed from its load balancer' do
      elb.stub :deregister_instances do |instance|
        elb.instances.delete instance
      end

      subject.detach(instance).should == elb.id
    end

    it 'returns nil if instance can\'t be removed from its load balancer' do
      elb.stub :deregister_instances

      subject.detach(instance).should be_nil
    end
  end
end
