# Elba
====

Command-line interface for Amazon's ELB

## Getting started

Elba relies on the excellent [Fog gem](http://fog.io/) to connect to Amazon's APIs.
Start by setting up your `~/.fog`:

    # ~/.fog
    :default:
      :aws_access_key_id:      ABCDEF....
      :aws_secret_access_key:  123456....

## Available Commands

    elba list
    elba attach <server_name> [load-balancer]
    elba detach <server_name>

Adding or removing a server will prompt the user which load balancer they wish the server to be removed from. Your AWS Access Key defines which environments you have access to and thus which load balancers will be listed and available.

## Examples

    $ elba list
    staging1
    loadtest
    affiliate-housetripdev-com
    staging-housetripdev-de

    $ elba add web[1-5]-r19.housetripdev.com [load balancer]
    > add to which load balancer?
      1. lb-production
      2. staging1
    $ 2
    > Successfully added `web1-r19.housetripdev.com` to load balancer `staging1`
    $
