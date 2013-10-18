# Elba

Command-line interface for Amazon's ELB

## Getting started

Elba relies on the excellent [Fog gem](http://fog.io/) to connect to Amazon's APIs.
Start by setting up your `~/.fog`:

    # ~/.fog
    :default:
      :aws_access_key_id:      ABCDEF....
      :aws_secret_access_key:  123456....

## Available Commands

    elba help              # prints this message
    elba list              # list available load balancers
    elba attach [INSTANCE] # attach an instance to a load balancer
    elba detach [INSTANCE] # detach an instance from a load balancer

Adding or removing a server will prompt the user which load balancer they wish the server to be removed from.
Your AWS Access Key defines which environments you have access to and thus which load balancers will be listed and available.

## Examples

    $ elba list
    Available Load Balancers:
    staging
     - i-xxxxxxxx
     - i-yyyyyyyy
    production
     - i-aaaaaaaa
     - i-bbbbbbbb
     - i-cccccccc

    $ elba attach i-xxxxxxxx
    More than one Load Balancer available, pick one in the list
    0 staging
    1 production
    Load Balancer: ["staging", "production"] staging
    Attaching foo to staging
    i-xxxxxxxx successfully added to staging

    $ elba attach i-xxxxxxxx
    i-xxxxxxxx is already attached to staging

    $ elba detach i-xxxxxxxx
    i-xxxxxxxx successfully removed from staging

    $ elba detach i-xxxxxxxx
    Unable to remove i-xxxxxxxx from staging
