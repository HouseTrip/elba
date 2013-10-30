module Elba
  module Mocks
    def test_config
      {
        region: 'eu-west-1',
        aws_access_key_id: 'JUST',
        aws_secret_access_key: 'TESTING'
      }
    end

    def test_elb_connection
      @connection ||= Fog::AWS::ELB.new(test_config)
    end

    def test_ec2_connection
      @ec2 ||= Fog::Compute::AWS.new(test_config)
    end

    def test_client
      Client.new test_elb_connection
    end

  end
end
