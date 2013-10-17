Elba
====

Command-line interface for Amazon's ELB


## Proposed `~/.elba` config

This would be a dotfile with yaml mapping environments to loadbalancers:

    :defaults:
      :staging:    'staging1'
      :production: 'lb-production-1'

## Proposed Commands

    elba status <load_balancer_name>
    elba add <load_balancer_name> <server_name>
    elba remove <load_balancer_name> <server_name>
