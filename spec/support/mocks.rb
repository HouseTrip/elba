module Elba
  module Mocks
    def test_config
      {
        region: 'eu-west-1',
        aws_access_key_id: 'JUST',
        aws_secret_access_key: 'TESTING'
      }
    end

    def test_client
      @client ||= Elba::Client.new(test_config).tap do |client|
        client.elb = test_elb_connection
        client.ec2 = test_ec2_connection
      end

    end

    def test_elb_connection
      @connection ||= Fog::AWS::ELB.new(test_config)
    end

    def test_ec2_connection
      @ec2 ||= Fog::Compute::AWS.new(test_config)
    end

  end
end
