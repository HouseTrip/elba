require 'spec_helper'
require 'elba/client'

describe Elba::Client do
  include Elba::Mocks

  context '.new' do
    it 'raises an error when missing credentials' do
      expect { described_class.new }.to raise_error(RuntimeError)
    end
  end


  describe '(an instance)' do
    subject   { described_class.new(test_config) }
    let(:elb) { subject.load_balancers.first }
    let(:ec2) { test_ec2_connection.servers.create region: test_config[:region] }

    before :each do
      if subject.load_balancers.empty?
        subject.connection.create_load_balancer([test_config[:region]], 'elba-test')
      end
    end


    describe '#load_balancers' do
      it 'does not raise NoMethodError' do
        expect(subject).to respond_to(:load_balancers)
      end

      it 'is delegated to the connection' do
        expect(subject.connection).to receive(:load_balancers)
        subject.load_balancers
      end
    end


    describe '#attach' do
      let(:perform) do
        subject.attach(ec2.id, elb,
          on_success: ->    { puts 'yay!' },
          on_failure: ->(x) { puts 'doh!' }
        )
      end

      it '(on success) executes success callback' do
        expect(capture(:stdout) { perform }).to include 'yay!'
      end

      it '(on failure) executes failure callback' do
        allow(elb).to receive(:register_instances).and_raise(Exception)
        expect(capture(:stdout) { perform }).to include 'doh!'
      end
    end


    describe '#detach' do
      before :each do
        subject.attach(ec2.id, elb, {})
      end

      let(:perform) do
        subject.detach(ec2.id, elb,
          on_success: ->    { puts 'yay!' },
          on_failure: ->(x) { puts 'doh!' }
        )
      end

      it '(on success) executes success callback' do
        expect(capture(:stdout) { perform }).to include 'yay!'
      end

      it '(on failure) executes failure callback' do
        allow(elb).to receive(:deregister_instances).and_raise(Exception)
        expect(capture(:stdout) { perform }).to include 'doh!'
      end
    end

  end
end
