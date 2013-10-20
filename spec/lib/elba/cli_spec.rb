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
      client.stub(:attach).and_raise(Elba::Client::MultipleLoadBalancersAvailable)
      subject.stub :ask => 0
      subject.stub :find_elb_from_choice => elb.id

      capture(:stdout) {
        subject.attach instance
      }.should include 'pick one in the list'
    end
  end
end
