require 'spec_helper'
require 'elba/cli'

describe Elba::Cli do
  include Elba::Mocks

  before :each do
    # Use test config
    subject.stub config: test_config

    # Create an ELB
    subject.client.connection.create_load_balancer([test_config[:region]], 'elba-test')
  end

  after :each do
    subject.client.load_balancers.map(&:destroy)
  end

  let(:elb)       { subject.elbs.first }
  let(:instance1) { test_ec2_connection.servers.create region: test_config[:region] }
  let(:instance2) { test_ec2_connection.servers.create region: test_config[:region] }

  describe 'help' do

    let(:output) { capture(:stdout) { subject.help } }

    it "can list" do
      output.should include "list"
    end

    it "can attach" do
      output.should include "attach"
    end

    it "can detach" do
      output.should include "detach"
    end
  end

  describe 'list' do
    it 'prints the list of available ELB' do
      output = capture(:stdout) {
        subject.list
      }

      output.should include "1 ELB found"
      output.should include " * #{elb.id}"
    end

    context '--instances' do
      it 'prints instances attached to each load balancer' do
        elb.stub instances: [instance1.id]

        output = capture(:stdout) {
          subject.list('--instances')
        }

        output.should include "1 ELB found"
        output.should include " * #{elb.id}"
        output.should include "  - #{instance1.id}"
      end
    end
  end

  describe 'attached' do
    let(:output)  { capture(:stdout) { perform } }
    let(:perform) { subject.attached elb.id }

    before do
      silence(:stdout) { subject.client.attach(instance1.id, elb) }
      silence(:stdout) { subject.client.attach(instance2.id, elb) }
    end

    it 'prints the list of instances attached to an ELB' do
      output.should include " * #{elb.id}"
      output.should include "  - #{instance1.id}"
      output.should include "  - #{instance2.id}"
    end

    context 'no balancer name is passed' do
      let(:perform) { subject.attached }

      it 'exits' do
        output.should include 'You must specify an ELB'
      end
    end

    context "the balancer can't be found" do
      let(:perform) { subject.attached 'yolo' }

      it 'exits' do
        output.should include 'Could not find balancer'
      end
    end

    context '--porcelain' do
      before do
        subject.stub options: { porcelain: true }
      end

      it 'prints the list of instances attached to an ELB without decoration' do
        output.should include "#{instance1.id} #{instance2.id}"
      end
    end
  end

  describe 'attach' do
    shared_examples_for "asking user" do
      before do
        subject.client.connection.create_load_balancer([test_config[:region]], 'elba-test-2')
      end

      it 'which load balancer to use' do
        allow(subject).to receive(:ask).and_return("0")

        output.should include "You must specify an ELB"
        output.should include "successfully"
      end
    end

    context 'instance1' do
      let(:perform) { subject.attach instance1.id  }
      let(:output)  { capture(:stdout) { perform } }

      it 'exits if no ELB available' do
        subject.stub elbs: []

        output.should include "No load balancer available"
      end

      it 'uses default ELB when only 1 available' do
        output.should include "Using default load balancer: #{elb.id}"
        output.should include "#{instance1.id} successfully attached to #{elb.id}"
      end

      it_should_behave_like "asking user"
    end

    context 'instance1 instance2' do
      let(:perform) { subject.attach instance1.id, instance2.id }
      let(:output)  { capture(:stdout) { perform } }

      it_should_behave_like "asking user"

      it 'works and reports success' do
        allow(subject).to receive(:ask).and_return("0")

        output.should include "#{instance1.id} successfully attached to #{elb.id}"
        output.should include "#{instance2.id} successfully attached to #{elb.id}"
      end
    end

    shared_examples_for "not asking user" do
      before do
        subject.client.connection.create_load_balancer([test_config[:region]], 'elba-test-2')
      end

      it 'which load balancer to use' do
        allow(subject).to receive(:ask)

        output.should_not include "No load balancer available"
        output.should_not include "Using default load balancer"
        output.should_not include "You must specify an ELB"
        expect(subject).to_not have_received(:ask)
      end
    end

    context '--to elb instance1' do
      let(:perform) do
        subject.stub options: {to: elb.id}
        subject.attach instance1.id
      end

      let(:output) { capture(:stdout) { perform } }

      it_should_behave_like "not asking user"

      it 'works and reports success' do
        output.should include "#{instance1.id} successfully attached to #{elb.id}"
      end
    end

    context '--to elb instance1 instance2' do
      let(:perform) do
        subject.stub options: {to: elb.id}
        subject.attach instance1.id, instance2.id
      end

      let(:output) { capture(:stdout) { perform } }

      it_should_behave_like "not asking user"

      it 'works and reports success' do
        output.should include "#{instance1.id} successfully attached to #{elb.id}"
        output.should include "#{instance2.id} successfully attached to #{elb.id}"
      end
    end

  end

  describe 'detach' do
    before do
      silence(:stdout) { subject.client.attach(instance1.id, elb, {}) }
    end

    let(:output) { capture(:stdout) { perform } }

    context 'instance1' do
      let(:perform) { subject.detach instance1.id }

      it 'works and reports success' do
        output.should include "#{instance1.id} successfully detached from #{elb.id}"
      end
    end

    context 'instance1 instance2' do
      before do
        silence(:stdout) { subject.client.attach(instance2.id, elb) }
      end

      let(:perform) { subject.detach instance1.id, instance2.id }

      it 'works and reports success' do
        output.should include "#{instance1.id}, #{instance2.id} successfully detached from #{elb.id}"
      end

      it 'warn if instances not attached to any ELB' do
        silence(:stdout) { subject.detach instance1.id, instance2.id }
        output.should include "Unable to find any ELB to detach #{instance1.id}, #{instance2.id}"
      end
    end

    context 'with 3 instances attached to 2 ELBs' do
      let(:instance3) { test_ec2_connection.servers.create region: test_config[:region] }
      let(:elb2)      { subject.client.load_balancers.find { |lb| lb.id == 'elba-test-2' } }

      describe 'detaching all instances at once' do
        before do
          subject.client.connection.create_load_balancer([test_config[:region]], 'elba-test-2')
          silence(:stdout) { subject.client.attach(instance2.id, elb) }
          silence(:stdout) { subject.client.attach(instance3.id, elb2) }
        end

        let(:output) { capture(:stdout) { subject.detach instance1.id, instance3.id, instance2.id } }

        it 'works like a charm' do
          output.should include "#{instance1.id}, #{instance2.id} successfully detached from #{elb.id}"
          output.should include "#{instance3.id} successfully detached from #{elb2.id}"
        end
      end
    end

  end
end
