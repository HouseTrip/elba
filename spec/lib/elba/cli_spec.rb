require 'spec_helper'
require 'elba/cli'

describe Elba::Cli do
  include Elba::Mocks

  before :each do
    # Use test config
    allow(subject).to receive(:config) { test_config }

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
      expect(output).to include "list"
    end

    it "can attach" do
      expect(output).to include "attach"
    end

    it "can detach" do
      expect(output).to include "detach"
    end
  end

  describe 'list' do
    it 'prints the list of available ELB' do
      output = capture(:stdout) {
        subject.list
      }

      expect(output).to include "1 ELB found"
      expect(output).to include " * #{elb.id}"
    end

    context '--instances' do
      it 'prints instances attached to each load balancer' do
        allow(elb).to receive(:instances) { [instance1.id] }

        output = capture(:stdout) {
          subject.list('--instances')
        }

        expect(output).to include "1 ELB found"
        expect(output).to include " * #{elb.id}"
        expect(output).to include "  - #{instance1.id}"
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
      expect(output).to include " * #{elb.id}"
      expect(output).to include "  - #{instance1.id}"
      expect(output).to include "  - #{instance2.id}"
    end

    context 'no balancer name is passed' do
      let(:perform) { subject.attached }

      it 'exits' do
        expect(output).to include 'You must specify an ELB'
      end
    end

    context "the balancer can't be found" do
      let(:perform) { subject.attached 'yolo' }

      it 'exits' do
        expect(output).to include 'Could not find balancer'
      end
    end

    context '--porcelain' do
      before do
        allow(subject).to receive(:options).and_return({ porcelain: true })
      end

      it 'prints the list of instances attached to an ELB without decoration' do
        expect(output).to include "#{instance1.id} #{instance2.id}"
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

        expect(output).to include "You must specify an ELB"
        expect(output).to include "successfully"
      end
    end

    context 'instance1' do
      let(:perform) { subject.attach instance1.id  }
      let(:output)  { capture(:stdout) { perform } }

      it 'exits if no ELB available' do
        allow(subject).to receive(:elbs) { [] }

        expect(output).to include "No load balancer available"
      end

      it 'uses default ELB when only 1 available' do
        expect(output).to include "Using default load balancer: #{elb.id}"
        expect(output).to include "#{instance1.id} successfully attached to #{elb.id}"
      end

      it_should_behave_like "asking user"
    end

    context 'instance1 instance2' do
      let(:perform) { subject.attach instance1.id, instance2.id }
      let(:output)  { capture(:stdout) { perform } }

      it_should_behave_like "asking user"

      it 'works and reports success' do
        allow(subject).to receive(:ask).and_return("0")

        expect(output).to include "#{instance1.id} successfully attached to #{elb.id}"
        expect(output).to include "#{instance2.id} successfully attached to #{elb.id}"
      end
    end

    shared_examples_for "not asking user" do
      before do
        subject.client.connection.create_load_balancer([test_config[:region]], 'elba-test-2')
      end

      it 'which load balancer to use' do
        allow(subject).to receive(:ask)

        expect(output).to_not include "No load balancer available"
        expect(output).to_not include "Using default load balancer"
        expect(output).to_not include "You must specify an ELB"
        expect(subject).to_not have_received(:ask)
      end
    end

    context '--to elb instance1' do
      let(:perform) do
        allow(subject).to receive(:options).and_return({ to: elb.id })
        subject.attach instance1.id
      end

      let(:output) { capture(:stdout) { perform } }

      it_should_behave_like "not asking user"

      it 'works and reports success' do
        expect(output).to include "#{instance1.id} successfully attached to #{elb.id}"
      end
    end

    context '--to elb instance1 instance2' do
      let(:perform) do
        allow(subject).to receive(:options).and_return({ to: elb.id })
        subject.attach instance1.id, instance2.id
      end

      let(:output) { capture(:stdout) { perform } }

      it_should_behave_like "not asking user"

      it 'works and reports success' do
        expect(output).to include "#{instance1.id} successfully attached to #{elb.id}"
        expect(output).to include "#{instance2.id} successfully attached to #{elb.id}"
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
        expect(output).to include "#{instance1.id} successfully detached from #{elb.id}"
      end
    end

    context 'instance1 instance2' do
      before do
        silence(:stdout) { subject.client.attach(instance2.id, elb) }
      end

      let(:perform) { subject.detach instance1.id, instance2.id }

      it 'works and reports success' do
        expect(output).to include "#{instance1.id}, #{instance2.id} successfully detached from #{elb.id}"
      end

      it 'warn if instances not attached to any ELB' do
        silence(:stdout) { subject.detach instance1.id, instance2.id }
        expect(output).to include "Unable to find any ELB to detach #{instance1.id}, #{instance2.id}"
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
          expect(output).to include "#{instance1.id}, #{instance2.id} successfully detached from #{elb.id}"
          expect(output).to include "#{instance3.id} successfully detached from #{elb2.id}"
        end
      end
    end

  end
end
