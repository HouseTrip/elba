module Elba
  module Mocks
    def test_region
      'eu-west-1'
    end

    def test_elb_connection
      Fog::AWS::ELB.new(test_credentials.merge(region: test_region))
    end

    def test_ec2_connection
      Fog::Compute::AWS.new(test_credentials.merge(region: test_region))
    end


    private

    def test_credentials
      {
        aws_access_key_id: 'JUST',
        aws_secret_access_key: 'TESTING'
      }
    end
  end
end
