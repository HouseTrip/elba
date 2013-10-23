require 'spec_helper'
require 'elba/cli'
require 'support/mocks'

describe Elba::Cli do
  include Elba::Mocks

  let(:elb) do
    test_elb_connection.tap do |c|
      # creates an ELB if none have been created yet
      c.create_load_balancer([test_region], 'elba-test') if c.load_balancers.empty?
    end.load_balancers.last
  end

  let(:instance1) { test_ec2_connection.servers.create region: test_region }
  let(:instance2) { test_ec2_connection.servers.create region: test_region }

  before :each do
    test_client.stub load_balancers: [elb]
    subject.stub client: test_client
  end

  describe 'help' do
    let(:output) { capture(:stdout) { subject.help } }

    it 'returns the available commands' do
      output.should include 'attach'
      output.should include 'detach'
      output.should include 'list'
    end
  end

  describe 'list' do
    before :each do
      subject.client.load_balancers[0].stub instances: [instance1.id, instance2.id]
    end

    it 'prints the list of available ELB' do
      capture(:stdout) { subject.list }.should include 'elba-test'
    end

    it '--instances prints the instances attached to each ELB' do
      (capture(:stdout) { subject.list '--instances' }.split & elb.instances).should eql elb.instances
    end
  end

  describe 'detach' do
    context 'a single instance' do

      before :each do
        subject.client.load_balancers[0].stub instances: [instance1.id]
      end

      it "notifies when successfuly detaching an instance" do
        capture(:stdout) {
          subject.detach instance1.id
        }.should include "#{instance1.id} successfully detached from elba-test"
      end

      it "warns if it can't detach an instance" do
        subject.client.stub detach: false

        capture(:stdout) {
          subject.detach instance1.id
        }.should include "Unable to detach #{instance1.id}"
      end

      it "warns when the load balancer is a figment of someone's imagination" do
        subject.client.stub(:detach).and_raise(Elba::Client::LoadBalancerNotFound)

        capture(:stdout) {
          subject.detach instance1.id
        }.should include "#{instance1.id} isn't attached to any known ELB"
      end
    end

    context 'multiple instances' do
      it 'confirms success when detaching multiple instances to an ELB' do
        subject.client.should_receive(:detach).with(instance1.id).and_return(elb)
        subject.client.should_receive(:detach).with(instance2.id).and_return(elb)

        output = capture(:stdout) {
          subject.detach instance1.id, instance2.id
        }

        output.should include "#{instance1.id} successfully detached from elba-test"
        output.should include "#{instance2.id} successfully detached from elba-test"
      end

      it "detaches an instance and warns when we have 2 instances, with 1 already attached" do
        subject.client.should_receive(:detach).with(instance1.id).and_raise(Elba::Client::LoadBalancerNotFound)
        subject.client.should_receive(:detach).with(instance2.id).and_return(elb)

        output = capture(:stdout) {
          subject.detach instance1.id, instance2.id
        }

        output.should include "#{instance1.id} isn't attached to any known ELB"
        output.should include "#{instance2.id} successfully detached from elba-test"
      end
    end

  end

  describe 'attach' do
    context 'a single instance' do
      it 'confirms success when attaching an instance to an ELB' do
        capture(:stdout) {
          subject.attach instance1.id
        }.should include 'successfully added'
      end

      it 'exits with a message when no ELB available' do
        subject.client.stub(:attach).and_raise(Elba::Client::NoLoadBalancerAvailable)

        capture(:stdout) {
          subject.attach instance1.id
        }.should include 'No ELB available'
      end

      it 'warns if instance is already attached to an ELB' do
        subject.client.stub(:attach).and_raise(Elba::Client::InstanceAlreadyAttached)

        capture(:stdout) {
          subject.attach instance1.id
        }.should include 'already attached'
      end

      it 'warns when given ELB is not found' do
        subject.client.stub(:attach).and_raise(Elba::Client::LoadBalancerNotFound)

        capture(:stdout) {
          subject.attach instance1.id
        }.should include 'ELB not found'
      end
    end

    context 'multiple instances' do
      it 'confirms success when attaching multiple instances to an ELB' do
        output = capture(:stdout) {
          subject.stub(:options).and_return({:to => elb.id})
          subject.attach instance1.id, instance2.id
        }

        output.should include "#{instance1.id} successfully added to elba-test"
        output.should include "#{instance2.id} successfully added to elba-test"
      end

      it 'attaches an instance and warns when we have 2 instances, with 1 already attached' do
        subject.client.stub :attach => elb.id

        subject.client.should_receive(:attach).with(instance1.id, 'elba-test').and_raise(Elba::Client::InstanceAlreadyAttached)
        subject.client.should_receive(:attach).with(instance2.id, 'elba-test').and_return(true)

        output = capture(:stdout) {
          subject.stub(:options).and_return({:to => 'elba-test'})
          subject.attach instance1.id, instance2.id
        }

        output.should include "#{instance1.id} is already attached to elba-test"
        output.should include "#{instance2.id} successfully added to elba-test"
      end

      it 'requires to specify the ELB' do
        output = capture(:stdout) {
          subject.attach instance1.id, instance2.id
        }.should include "You must specify which ELB to use when attaching mulitple instances"
      end
    end
  end
end
