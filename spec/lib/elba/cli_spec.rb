require 'spec_helper'
require 'elba/cli'

describe Elba::Cli do

  let(:elb)    { double :id => 'elba-test' }
  let(:client) { double :load_balancers => [elb] }

  before :each do
    subject.stub :client => client
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
    let(:instances) { ['x-00000000', 'x-00000001'] }

    before :each do
      elb.stub :instances => instances
    end

    it 'prints the list of available ELB' do
      capture(:stdout) { subject.list }.should include 'elba-test'
    end

    it 'with -i option, prints the list of available ELB with instances attached' do
      (capture(:stdout) { subject.list '-i' }.split & instances).should eql instances
    end
  end

  describe 'attach' do
    let(:instance) { 'x-00000000' }

    context "with single instance" do
      it 'confirms success when attaching an instance to an ELB' do
        client.stub :attach => elb.id

        capture(:stdout) {
          subject.attach instance, elb.id
        }.should include 'successfully added'
      end

      it 'exits with a message when no ELB available' do
        client.stub(:attach).and_raise(Elba::Client::NoLoadBalancerAvailable)

        capture(:stdout) {
          subject.attach instance
        }.should include 'No ELB available'
      end

      it 'warns if instance is already attached to an ELB' do
        client.stub(:attach).and_raise(Elba::Client::InstanceAlreadyAttached)

        capture(:stdout) {
          subject.attach instance, elb.id
        }.should include 'already attached'
      end

      it 'warns when given ELB is not found' do
        client.stub(:attach).and_raise(Elba::Client::LoadBalancerNotFound)

        capture(:stdout) {
          subject.attach instance, 'unknown'
        }.should include 'ELB not found'
      end

      it 'asks when no ELB given and more than 1 available' do
        # simulate our mock client having two load balancers and raising the appropriate error.
        elb2 = double :id => 'elba-test-2'
        client.stub(:load_balancers => [elb, elb2])
        client.should_receive(:attach).with('x-00000000', nil).and_raise(Elba::Client::MultipleLoadBalancersAvailable)
        client.should_receive(:attach).with('x-00000000', 'elba-test-2').and_return(true)

        expect($stdin).to receive(:gets).and_return('1')

        output = capture(:stdout) do
          subject.attach instance
        end

        output.should include('More than one ELB available, pick one in the list')
        output.should include('0  elba-test')
        output.should include('1  elba-test-2')
      end
    end

    context "with multiple instances" do
      let(:instances) { ['x-00000000', 'x-00000001']  }

      it 'confirms success when attaching multiple instances to an ELB' do
        client.stub :attach => elb.id

        output = capture(:stdout) {
          subject.attach instances, elb.id
        }

        output.should include 'x-00000000 successfully added to elba-test'
        output.should include 'x-00000001 successfully added to elba-test'
      end

      it "attaches an instance and warns when we have 2 instances, with 1 already attached" do
        client.stub :attach => elb.id

        client.should_receive(:attach).with('x-00000000', 'elba-test').and_raise(Elba::Client::InstanceAlreadyAttached)
        client.should_receive(:attach).with('x-00000001', 'elba-test').and_return(true)

        output = capture(:stdout) {
          subject.attach instances, elb.id
        }

        output.should include 'x-00000000 is already attached to elba-test'
        output.should include 'x-00000001 successfully added to elba-test'
      end
    end
  end
end
